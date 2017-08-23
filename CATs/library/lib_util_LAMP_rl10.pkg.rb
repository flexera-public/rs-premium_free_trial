name "LIB - LAMP Definitions RL10"
rs_ca_ver 20160622
short_description "RCL definitions used for launching a LAMP stack."

package "pft/rl10/lamp_utilities"

import "pft/server_templates_utilities"
import "pft/cloud_utilities"
import "pft/creds_utilities"
import "pft/rl10/lamp_resources"
import "pft/err_utilities", as: "functions"


define launcher(@chef_server, @lb_server, @app_server, @db_server, @ssh_key, @sec_group, @sec_group_rule_ssh, @sec_group_rule_http, @sec_group_rule_https, @sec_group_rule_http8080, @sec_group_rule_mysql, @placement_group, $param_costcenter, $map_cloud, $map_st, $param_location, $inAzure, $invSphere, $needsSshKey, $needsPlacementGroup, $needsSecurityGroup, $param_chef_password)  return @lb_server, @app_server, @db_server, @sec_group, @ssh_key, @placement_group, $site_link, $lb_status_link do

  # Need the cloud name later on
  $cloud_name = map( $map_cloud, $param_location, "cloud" )

  # Check if the selected cloud is supported in this account.
  # Since different PIB scenarios include different clouds, this check is needed.
  # It raises an error if not which stops execution at that point.
  call cloud_utilities.checkCloudSupport($cloud_name, $param_location)

  # Find and import the server template - just in case it hasn't been imported to the account already
  # call server_templates_utilities.importServerTemplate($map_st)

  call creds_utilities.createCreds(["CAT_MYSQL_ROOT_PASSWORD","CAT_MYSQL_APP_PASSWORD","CAT_MYSQL_APP_USERNAME"])

  call launch_resources(@chef_server, @lb_server, @app_server, @db_server, @ssh_key, @sec_group, @sec_group_rule_ssh, @sec_group_rule_http, @sec_group_rule_https, @sec_group_rule_http8080, @sec_group_rule_mysql, @placement_group, $param_costcenter, $inAzure, $invSphere, $needsSshKey, $needsPlacementGroup, $needsSecurityGroup, $cloud_name, $param_chef_password)  retrieve @lb_server, @app_server, @db_server, @sec_group, @ssh_key, @placement_group, $site_link, $lb_status_link

end


define launch_resources(@chef_server, @lb_server, @app_server, @db_server, @ssh_key, @sec_group, @sec_group_rule_ssh, @sec_group_rule_http, @sec_group_rule_https, @sec_group_rule_http8080, @sec_group_rule_mysql, @placement_group, $param_costcenter, $inAzure, $invSphere, $needsSshKey, $needsPlacementGroup, $needsSecurityGroup, $cloud_name, $param_chef_password)  return @lb_server, @app_server, @db_server, @sec_group, @ssh_key, @placement_group, $site_link, $lb_status_link do
  # Stash some definitions in case the chef-server needs to be provisioned
  $ssh_key = to_object(@ssh_key)
  $sec_group = to_object(@sec_group)
  $sec_group_rule_ssh = to_object(@sec_group_rule_ssh)
  $sec_group_rule_https = to_object(@sec_group_rule_https)
  $placement_group = to_object(@placement_group)

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
  elsif $invSphere # need to change the chef server to use its private IP for the chef URL
    call functions.log("Tweaking chef_hash for VMware - before tweak", to_s($chef_hash))
    $chef_hash["fields"]["inputs"]["CHEF_SERVER_FQDN"] = "env:PRIVATE_IP"
    call functions.log("Tweaking chef_hash for VMware - after tweak", to_s($chef_hash))
  end

  ##############################################################################
  # CHEF SERVER
  # Launch the chef server first and wait, it is a prereq.
  ##############################################################################
  @deployment = rs_cm.deployments.empty()
  $tags = rs_cm.tags.by_tag(resource_type:"deployments", tags:["pft:role=shared"])
  call functions.log("deployment_tags", to_json($tags))
  if (empty?($tags[0]))
    call functions.log("deployment_create", "Creating deployment")
    @deployment = rs_cm.deployment.create(name:join(["PFT Shared Services-",uuid()]))
    rs_cm.tags.multi_add(resource_hrefs:[@deployment.href], tags:["pft:role=shared"])
  else
    call functions.log("deployment_update", "found deployment")
    $deployment_href = $tags[0][0]["links"][0]["href"]
    @deployment = rs_cm.get(href: $deployment_href)
  end

  @chef_servers = rs_cm.instances.empty()

  if (!empty?(@deployment.servers()))
    @servers = @deployment.servers()
    call functions.log("Found servers in the shared deployment", to_json(to_object(@servers)))
    @active_servers = select(@servers, { state: "operational" })
    if (!empty?(@active_servers))
      @current_instance = @active_servers.current_instance()
      call functions.log("Found operational servers in the shared deployment", to_json(to_object(@current_instance)))
    end

    if (!empty?(@current_instance))
      call functions.log("Searching current instances for chef server tag", to_json(to_object(@current_instance)))
      $instance_tags = rs_cm.tags.by_resource(resource_hrefs:@current_instance.href[])
      $tags, @chef_servers = map $instance_tag in $instance_tags[0] return $tag, @instance do
        $tag = select($instance_tag["tags"], {"name": "pft:role=chef_server"})
        if (!empty?($tag))
          @instance = rs_cm.get(href: $instance_tag["links"][0]["href"])
          call functions.log("Returning an instance with the tag", to_json(to_object(@instance)))
        end
      end
    end
  end

  if (empty?(@chef_servers))
    $chef_hash["fields"]["deployment_href"] = @deployment.href

    @password_cred = rs_cm.credentials.get(filter: ["name==PFT_LAMP_Chef_Admin_Password"])
    if (empty?(@password_cred))
      rs_cm.credentials.create(credential: {name: "PFT_LAMP_Chef_Admin_Password", value: $param_chef_password})
    else
      @password_cred.update(credential: { value: $param_chef_password })
    end

    @cloud = rs_cm.get(href: $chef_hash["fields"]["cloud_href"])

    if $needsSshKey
      @chef_ssh_key = @cloud.ssh_keys(filter: ["name==pft_chef_server"])
      if(empty?(@chef_ssh_key))
        $ssh_key["fields"]["name"] = "pft_chef_server"
        @chef_ssh_key = @cloud.ssh_keys().create(ssh_key: $ssh_key["fields"])
      end
      $chef_hash["fields"]["ssh_key_href"] = @chef_ssh_key.href
    end

    if $needsSecurityGroup
      @chef_sec_group = @cloud.security_groups(filter: ["name==pft_chef_server"])
      if(empty?(@chef_sec_group))
        $sec_group["fields"]["name"] = "pft_chef_server"
        $sec_group["fields"]["deployment_href"] = null
        @chef_sec_group = @cloud.security_groups().create(security_group: $sec_group["fields"])

        $sec_group_rule_ssh["fields"]["security_group_href"] = @chef_sec_group.href
        rs_cm.security_group_rules.create(security_group_rule: $sec_group_rule_ssh["fields"])

        $sec_group_rule_https["fields"]["security_group_href"] = @chef_sec_group.href
        rs_cm.security_group_rules.create(security_group_rule: $sec_group_rule_https["fields"])
      end
      $chef_hash["fields"]["security_group_hrefs"] = @chef_sec_group.href[]
    end

    if $needsPlacementGroup
      @chef_placement_group = rs_cm.placement_groups.get(filter: ["name==pft_chef_server"])
      if (empty?(@chef_placement_group))
        $placement_group["fields"]["name"] = "pft_chef_server"
        $placement_group["fields"]["deployment_href"] = null
        @chef_placement_group = rs_cm.placement_groups.create(placement_group: $placement_group["fields"])
      end
      $chef_hash["fields"]["placement_group_href"] = @chef_placement_group.href
    end

    @chef_server = $chef_hash
    provision(@chef_server)
    @chef_server.get()
    rs_cm.tags.multi_add(resource_hrefs:[@chef_server.current_instance().href], tags:["pft:role=chef_server"])
  end
  ##############################################################################
  # /CHEF SERVER
  ##############################################################################

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

  # Update app code
  call server_templates_utilities.run_script_no_inputs(@app_server, "PHP Appserver Install - chef")
  # Reconnect to DB
  call server_templates_utilities.run_script_no_inputs(@app_server, "PFT DB Config")


end
