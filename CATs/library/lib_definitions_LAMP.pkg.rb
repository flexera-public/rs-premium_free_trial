name "LIB - LAMP Definitions"
rs_ca_ver 20160622
short_description "RCL definitions used for launching a LAMP stack."

package "definitions/lamp"

import "util/server_templates"
import "common/lamp_resources"


define launch_servers(@lb_server, @app_server, @db_server, @ssh_key, @sec_group, @sec_group_rule_http, @sec_group_rule_http8080, @sec_group_rule_mysql, @placement_group, $param_costcenter, $map_cloud, $map_st, $map_db_creds, $param_location, $inAzure, $invSphere, $needsSshKey, $needsPlacementGroup, $needsSecurityGroup)  return @lb_server, @app_server, @db_server, @sec_group, @ssh_key, @placement_group, $site_link, $lb_status_link do 

  # Need the cloud name later on
  $cloud_name = map( $map_cloud, $param_location, "cloud" )

  # Check if the selected cloud is supported in this account.
  # Since different PIB scenarios include different clouds, this check is needed.
  # It raises an error if not which stops execution at that point.
  call cloud.checkCloudSupport($cloud_name, $param_location)
  
  # Find and import the server template - just in case it hasn't been imported to the account already
  call server_templates.importServerTemplate($map_st)
  
  call creds.createCreds(["CAT_MYSQL_ROOT_PASSWORD","CAT_MYSQL_APP_PASSWORD","CAT_MYSQL_APP_USERNAME"])
    
  # Provision the resources
  
  # Provision the SSH key if applicable.
  if $needsSshKey
    provision(@ssh_key)
  end
  
  # Provision the security group rules if applicable. (The security group itself is created when the server is provisioned.)
  if $needsSecurityGroup
    provision(@sec_group_rule_http)
    provision(@sec_group_rule_http8080)
    provision(@sec_group_rule_mysql)
  end
  
  # Provision the placement group if applicable
  if $needsPlacementGroup
      provision(@placement_group)
  end
  
  # Launch the servers concurrently
  concurrent return  @lb_server, @app_server, @db_server do 
    sub task_name:"Launch DB" do
      task_label("Launching DB")
      $db_retries = 0 
      sub on_error: functions.handle_retries($db_retries) do
        $db_retries = $db_retries + 1
        provision(@db_server)
      end
    end
    sub task_name:"Launch LB" do
      task_label("Launching LB")
      $lb_retries = 0 
      sub on_error: functions.handle_retries($lb_retries) do
        $lb_retries = $lb_retries + 1
        provision(@lb_server)
      end
    end
    
    sub task_name:"Launch Application Tier" do
      task_label("Launching Application Tier")
      $apptier_retries = 0 
      sub on_error: functions.handle_retries($apptier_retries) do
        $apptier_retries = $apptier_retries + 1
        provision(@app_server)
      end
    end
  end
  
  concurrent do  
    # Enable monitoring for server-specific application software
    call server_templates.run_recipe_no_inputs(@lb_server, "rs-haproxy::collectd")
    call server_templates.run_recipe_no_inputs(@app_server, "rs-application_php::collectd")  
    call server_templates.run_recipe_no_inputs(@db_server, "rs-mysql::collectd")   
    
    # Import a test database
    call server_templates.run_recipe_no_inputs(@db_server, "rs-mysql::dump_import")  # applicable inputs were set at launch
    
    # Set up the tags for the load balancer and app servers to find each other.
    call server_templates.run_recipe_no_inputs(@lb_server, "rs-haproxy::tags")
    call server_templates.run_recipe_no_inputs(@app_server, "rs-application_php::tags")  
    
    # Due to the concurrent launch above, it's possible the app server came up before the DB server and wasn't able to connect.
    # So, we re-run the application setup script to force it to connect.
    call server_templates.run_recipe_no_inputs(@app_server, "rs-application_php::default")
  end
    
  # Now that all the servers are good to go, tell the LB to find the app server.
  # This must run after the tagging is complete, so it is done outside the concurrent block above.
  call server_templates.run_recipe_no_inputs(@lb_server, "rs-haproxy::frontend")
    
  # Now tag the servers with the selected project cost center ID.
  $tags=[join(["costcenter:id=",$param_costcenter])]
  rs_cm.tags.multi_add(resource_hrefs: @@deployment.servers().current_instance().href[], tags: $tags)
  rs_cm.tags.multi_add(resource_hrefs: @@deployment.server_arrays().current_instances().href[], tags: $tags)

  # If deployed in Azure one needs to provide the port mapping that Azure uses.
  if $inAzure
     @bindings = rs_cm.clouds.get(href: @lb_server.current_instance().cloud().href).ip_address_bindings(filter: ["instance_href==" + @lb_server.current_instance().href])
     @binding = select(@bindings, {"private_port":80})
     $server_addr = join([to_s(@lb_server.current_instance().public_ip_addresses[0]), ":", @binding.public_port])
  else
    if $invSphere  # Use private IP for VMware envs
        # Wait for the server to get the IP address we're looking for.
        while equals?(@lb_server.current_instance().private_ip_addresses[0], null) do
          sleep(10)
        end
        $server_addr =  to_s(@lb_server.current_instance().private_ip_addresses[0])
    else
        # Wait for the server to get the IP address we're looking for.
        while equals?(@lb_server.current_instance().public_ip_addresses[0], null) do
          sleep(10)
        end
        $server_addr =  to_s(@lb_server.current_instance().public_ip_addresses[0])
    end
  end
  $site_link = join(["http://", $server_addr, "/dbread"])
  $lb_status_link = join(["http://", $server_addr, "/haproxy-status"])
end 

# Install a new branch of app code to change colors and some text on the webpage.
define install_appcode($param_appcode, @app_server) do
  
  # Parse the parameter for the repo and branch information  
  $repo_branch = split($param_appcode, " ")[1]
  $repo = split($repo_branch, ":")[0]
  $branch = split($repo_branch, ":")[1]
  
  # Create an input hash for the give repo and branch and then update the deployment level, server array, and any 
  # existing server level Inputs with the value.
  $inp = {
    "rs-application_php/scm/repository" : join(["text:git://",$repo,".git"]),
    "rs-application_php/scm/revision" : join(["text:",$branch]) 
  }
  
  @@deployment.multi_update_inputs(inputs: $inp) 
  @app_server.next_instance().multi_update_inputs(inputs: $inp)
  @app_server.current_instances().multi_update_inputs(inputs: $inp)

  # Call the operational recipe to apply the new code
  call server_templates.run_recipe_no_inputs(@app_server, "rs-application_php::default")
end
