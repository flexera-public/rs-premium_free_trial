name "LIB - LAMP Definitions RL10"
rs_ca_ver 20160622
short_description "RCL definitions used for launching a LAMP stack."

package "pft/rl10/lamp_utilities"

import "pft/server_templates_utilities"
import "pft/cloud_utilities"
import "pft/creds_utilities"
import "pft/rl10/lamp_resources"
import "pft/err_utilities", as: "functions"


define launcher(@chef_server, @lb_server, @app_server, @db_server, @ssh_key, @sec_group, @sec_group_rule_ssh, @sec_group_rule_http, @sec_group_rule_https, @sec_group_rule_http8080, @sec_group_rule_mysql, @placement_group, $param_costcenter, $map_cloud, $map_st, $param_location, $inAzure, $invSphere, $needsSshKey, $needsPlacementGroup, $needsSecurityGroup)  return @chef_server, @lb_server, @app_server, @db_server, @sec_group, @ssh_key, @placement_group, $site_link, $lb_status_link do

  # Need the cloud name later on
  $cloud_name = map( $map_cloud, $param_location, "cloud" )

  # Check if the selected cloud is supported in this account.
  # Since different PIB scenarios include different clouds, this check is needed.
  # It raises an error if not which stops execution at that point.
  call cloud_utilities.checkCloudSupport($cloud_name, $param_location)

  # Find and import the server template - just in case it hasn't been imported to the account already
  # call server_templates_utilities.importServerTemplate($map_st)

  call creds_utilities.createCreds(["CAT_MYSQL_ROOT_PASSWORD","CAT_MYSQL_APP_PASSWORD","CAT_MYSQL_APP_USERNAME"])

  call launch_resources(@chef_server, @lb_server, @app_server, @db_server, @ssh_key, @sec_group, @sec_group_rule_ssh, @sec_group_rule_http, @sec_group_rule_https, @sec_group_rule_http8080, @sec_group_rule_mysql, @placement_group, $param_costcenter, $inAzure, $invSphere, $needsSshKey, $needsPlacementGroup, $needsSecurityGroup, $cloud_name)  retrieve @chef_server, @lb_server, @app_server, @db_server, @sec_group, @ssh_key, @placement_group, $site_link, $lb_status_link

end


define launch_resources(@chef_server, @lb_server, @app_server, @db_server, @ssh_key, @sec_group, @sec_group_rule_ssh, @sec_group_rule_http, @sec_group_rule_https, @sec_group_rule_http8080, @sec_group_rule_mysql, @placement_group, $param_costcenter, $inAzure, $invSphere, $needsSshKey, $needsPlacementGroup, $needsSecurityGroup, $cloud_name)  return @chef_server, @lb_server, @app_server, @db_server, @sec_group, @ssh_key, @placement_group, $site_link, $lb_status_link do

  # Provision the resources

  # Provision the SSH key if applicable.
  if $needsSshKey
    provision(@ssh_key)
  end

  # Provision the security group rules if applicable. (The security group itself is created when the server is provisioned.)
  if $needsSecurityGroup
    provision(@sec_group_rule_ssh)
    provision(@sec_group_rule_http)
    provision(@sec_group_rule_https)
    provision(@sec_group_rule_http8080)
    provision(@sec_group_rule_mysql)
  end

  # Provision the placement group if applicable
  if $needsPlacementGroup
    provision(@placement_group)
  end

  $chef_hash = to_object(@chef_server)
  $lb_hash = to_object(@lb_server)
  $webtier_hash = to_object(@app_server)

  $db_hash = to_object(@db_server)

  if $cloud_name == "Google"
    @cloud = rs_cm.clouds.get(filter: ["name==Google"])

    if (size(@cloud) > 0)
      @images = @cloud.images(filter: ["name==ubuntu-1404-trusty-v"])  # partial match is all we need
      @image = last(@images)  # just grab one of them should be ok - may have to do some better regexp matching
      $image_href = @image.href
      $chef_hash["fields"]["image_href"] = $image_href
      $lb_hash["fields"]["image_href"] = $image_href
      $webtier_hash["fields"]["image_href"] = $image_href
      $db_hash["fields"]["image_href"] = $image_href
    end
  end

  ##############################################################################
  # CHEF SERVER
  # Launch the chef server first and wait, it is a prereq.
  ##############################################################################
  @chef_server = $chef_hash
  provision(@chef_server)

  $key_tagval = tag_value(@chef_server.current_instance(), 'chef_org_validator:pft')
  $key = gsub(gsub($key_tagval, ',', '\n'), 'eq;', '=')
  $key_credname = 'PFT-LAMP-ChefValidator-'+last(split(@@deployment.href,"/"))
  rs_cm.credentials.create(credential: {name: $key_credname, value: $key})

  $cert_tagval = tag_value(@chef_server.current_instance(), 'chef_server:ssl_cert')
  $cert = gsub(gsub($cert_tagval, ',', '\n'), 'eq;', '=')
  $cert_credname = 'PFT-LAMP-ChefCert-'+last(split(@@deployment.href,"/"))
  rs_cm.credentials.create(credential: {name: $cert_credname, value: $cert})

  rs_cm.tags.multi_delete(resource_hrefs: @chef_server.href[], tags: ["chef_org_validator:pft="+$key_tagval,"chef_server:ssl_cert="+$cert_tagval])
  ##############################################################################
  # /CHEF SERVER
  ##############################################################################

  $lb_hash["fields"]["inputs"]["CHEF_SERVER_URL"] = join(['text:https://',@chef_server.current_instance().public_ip_addresses[0],'/organizations/pft'])
  $webtier_hash["fields"]["inputs"]["CHEF_SERVER_URL"] = join(['text:https://',@chef_server.current_instance().public_ip_addresses[0],'/organizations/pft'])
  $db_hash["fields"]["inputs"]["CHEF_SERVER_URL"] = join(['text:https://',@chef_server.current_instance().public_ip_addresses[0],'/organizations/pft'])

  @lb_server = $lb_hash
  @app_server = $webtier_hash
  @db_server = $db_hash

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

define delete_resources() do
  $key_credname = 'PFT-LAMP-ChefValidator-'+last(split(@@deployment.href,"/"))
  @key_cred = rs_cm.credentials.get(filter:["name=="+$key_credname])
  @key_cred.destroy()


  $cert_credname = 'PFT-LAMP-ChefCert-'+last(split(@@deployment.href,"/"))
  @cert_cred = rs_cm.credentials.get(filter:["name=="+$cert_credname])
  @cert_cred.destroy()
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
    "SCM_REPOSITORY" : join(["text:git://",$repo,".git"]),
    "SCM_REVISION" : join(["text:",$branch])
  }

  @@deployment.multi_update_inputs(inputs: $inp)
  @app_server.next_instance().multi_update_inputs(inputs: $inp)
  @app_server.current_instances().multi_update_inputs(inputs: $inp)

  # Call the operational recipe to apply the new code
  #call server_templates_utilities.run_recipe_no_inputs(@app_server, "rs-application_php::default")
  # TODO: This needs to be thought through. I could just run "PHP Appserver Install - chef" but
  # idempotency might mean that nothing happens. May need to delete the deploy dir first, or
  # just run a custom script to override the contents of the applicatoin deploy dir.
  #call server_templates_utilities.run_script_no_inputs(@lb_server, "HAProxy Frontend - chef")

end
