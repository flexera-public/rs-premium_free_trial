#Copyright 2015 RightScale
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.

#RightScale Cloud Application Template (CAT)

# DESCRIPTION
# Deploys a basic 3-Tier LAMP Stack.
# 
# FEATURES
# User can select cloud at launch.
# User can use a post-launch action to install a different version of the application software from a Git repo.


name 'LAMP Stack'
rs_ca_ver 20160622
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/lamp_icon.png)

Launches a 3-tier LAMP stack."
long_description "Launches a 3-tier LAMP stack.\n
Clouds Supported: <B>AWS, Azure</B>"

import "common/parameters"
import "common/mappings"
import "common/conditions"
import "common/resources"
import "util/server_templates"
import "util/err"
import "util/cloud"
import "util/creds"

##################
# User inputs    #
##################
parameter "param_location" do
  like $parameters.param_location

  allowed_values "AWS", "Azure"
  default "AWS"
end

parameter "param_appcode" do 
  category "Application Code"
  label "Repository and Branch" 
  type "string" 
  allowed_values "(Yellow) github.com/rightscale/examples:unified_php", "(Blue) github.com/rs-services/rs-premium_free_trial:unified_php_modified" 
  default "(Blue) github.com/rs-services/rs-premium_free_trial:unified_php_modified"
  operations "update_app_code"
end

parameter "param_costcenter" do 
  like $parameters.param_costcenter
end

################################
# Outputs returned to the user #
################################
output "site_url" do
  label "Web Site URL"
  category "Output"
  description "Click to see your web site."
end

output "lb_status" do
  label "Load Balancer Status Page" 
  category "Output"
  description "Accesses Load Balancer status page"
end

output "app1_github_link" do
  label "Yellow Application Code"
  category "Code Repositories"
  description "\"Yellow\" application repo. (The main change is in the style.css file.)"
  default_value "https://github.com/rightscale/examples/tree/unified_php"
end

output "app2_github_link" do
  label "Blue Application Code"
  category "Code Repositories"
  description "\"Blue\" application repo. (The main change is in the style.css file.)"
  default_value "https://github.com/rs-services/rs-premium_free_trial/tree/unified_php_modified"
end


##############
# MAPPINGS   #
##############

# Mapping and abstraction of cloud-related items.
mapping "map_cloud" do 
  like $mappings.map_cloud
end

# Mapping of which ServerTemplates and Revisions to use for each tier.
mapping "map_st" do {
  "lb" => {
    "name" => "Load Balancer with HAProxy (v14.1.1)",
    "rev" => "43",
  },
  "app" => {
    "name" => "PHP App Server (v14.1.1)",
    "rev" => "44",
  },
  "db" => {
    "name" => "Database Manager for MySQL (v14.1.1)",
    "rev" => "56",
  }
} end

mapping "map_mci" do {
  "VMware" => { # vSphere 
    "mci_name" => "RightImage_CentOS_6.6_x64_v14.2_VMware",
    "mci_rev" => "9",
  },
  "Public" => { # all other clouds
    "mci_name" => "RightImage_CentOS_6.6_x64_v14.2",
    "mci_rev" => "24",
  }
} end

# Mapping of names of the creds to use for the DB-related credential items.
# Allows for easier maintenance down the road if needed.
mapping "map_db_creds" do {
  "root_password" => {
    "name" => "CAT_MYSQL_ROOT_PASSWORD",
  },
  "app_username" => {
    "name" => "CAT_MYSQL_APP_USERNAME",
  },
  "app_password" => {
    "name" => "CAT_MYSQL_APP_PASSWORD",
  }
} end


##################
# CONDITIONS     #
##################

# Used to decide whether or not to pass an SSH key or security group when creating the servers.
condition "needsSshKey" do
  like $conditions.needsSshKey
end

condition "needsSecurityGroup" do
  like $conditions.needsSecurityGroup
end

condition "needsPlacementGroup" do
  like $conditions.needsPlacementGroup
end

condition "invSphere" do
  like $conditions.invSphere
end

condition "inAzure" do
  like $conditions.inAzure
end  


############################
# RESOURCE DEFINITIONS     #
############################

### Server Declarations ###
resource 'lb_server', type: 'server' do
  name join(['LB-',last(split(@@deployment.href,"/"))])
  cloud map( $map_cloud, $param_location, "cloud" )
  datacenter map($map_cloud, $param_location, "zone")
  instance_type map($map_cloud, $param_location, "instance_type")
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  placement_group_href map($map_cloud, $param_location, "pg")
  security_group_hrefs map($map_cloud, $param_location, "sg") 
  server_template find(map($map_st, "lb", "name"), revision: map($map_st, "lb", "rev"))
  multi_cloud_image_href find(map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_name"), revision: map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_rev"))
  inputs do {
    'ephemeral_lvm/logical_volume_name' => 'text:ephemeral0',
    'ephemeral_lvm/logical_volume_size' => 'text:100%VG',
    'ephemeral_lvm/mount_point' => 'text:/mnt/ephemeral',
    'ephemeral_lvm/stripe_size' => 'text:512',
    'ephemeral_lvm/volume_group_name' => 'text:vg-data',
    'rs-base/ntp/servers' => 'array:["text:time.rightscale.com","text:ec2-us-east.time.rightscale.com","text:ec2-us-west.time.rightscale.com"]',
    'rs-base/swap/size' => 'text:1',
    'rs-haproxy/balance_algorithm' => 'text:roundrobin',
    'rs-haproxy/health_check_uri' => 'text:/',
    'rs-haproxy/incoming_port' => 'text:80',
    'rs-haproxy/pools' => 'array:["text:default"]',
    'rs-haproxy/schedule/enable' => 'text:true',
    'rs-haproxy/schedule/interval' => 'text:15',
    'rs-haproxy/session_stickiness' => 'text:false',
    'rs-haproxy/stats_uri' => 'text:/haproxy-status',
    "rightscale/security_updates" => "text:enable", # Enable security updates
  } end
end

resource 'db_server', type: 'server' do
  like @lb_server

  name join(['DB-',last(split(@@deployment.href,"/"))])
  server_template find(map($map_st, "db", "name"), revision: map($map_st, "db", "rev"))
  inputs do {
    'ephemeral_lvm/logical_volume_name' => 'text:ephemeral0',
    'ephemeral_lvm/logical_volume_size' => 'text:100%VG',
    'ephemeral_lvm/mount_point' => 'text:/mnt/ephemeral',
    'ephemeral_lvm/stripe_size' => 'text:512',
    'ephemeral_lvm/volume_group_name' => 'text:vg-data',
    'rs-base/ntp/servers' => 'array:["text:time.rightscale.com","text:ec2-us-east.time.rightscale.com","text:ec2-us-west.time.rightscale.com"]',
    'rs-base/swap/size' => 'text:1',
    'rs-mysql/application_user_privileges' => 'array:["text:select","text:update","text:insert"]',
    'rs-mysql/backup/keep/dailies' => 'text:14',
    'rs-mysql/backup/keep/keep_last' => 'text:60',
    'rs-mysql/backup/keep/monthlies' => 'text:12',
    'rs-mysql/backup/keep/weeklies' => 'text:6',
    'rs-mysql/backup/keep/yearlies' => 'text:2',
    'rs-mysql/bind_network_interface' => 'text:private',
    'rs-mysql/device/count' => 'text:2',
    'rs-mysql/device/destroy_on_decommission' => 'text:false',
    'rs-mysql/device/detach_timeout' => 'text:300',
    'rs-mysql/device/mount_point' => 'text:/mnt/storage',
    'rs-mysql/device/nickname' => 'text:data_storage',
    'rs-mysql/device/volume_size' => 'text:10',
    'rs-mysql/schedule/enable' => 'text:false',
    'rs-mysql/server_usage' => 'text:dedicated',
    'rs-mysql/backup/lineage' => 'text:demolineage',
    'rs-mysql/server_root_password' => "cred:CAT_MYSQL_ROOT_PASSWORD",
    'rs-mysql/application_password' => "cred:CAT_MYSQL_APP_PASSWORD",
    'rs-mysql/application_username' => "cred:CAT_MYSQL_APP_USERNAME",
    'rs-mysql/application_database_name' => 'text:app_test',
    'rs-mysql/import/dump_file' => 'text:app_test.sql',
    'rs-mysql/import/repository' => 'text:git://github.com/rightscale/examples.git',
    'rs-mysql/import/revision' => 'text:unified_php',
  } end
end

resource 'app_server', type: 'server_array' do
  name join(['App-',last(split(@@deployment.href,"/"))])
  cloud map( $map_cloud, $param_location, "cloud" )
  datacenter map($map_cloud, $param_location, "zone")
  instance_type map($map_cloud, $param_location, "instance_type")
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  placement_group_href map($map_cloud, $param_location, "pg")
  security_group_hrefs map($map_cloud, $param_location, "sg") 
  multi_cloud_image_href find(map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_name"), revision: map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_rev"))
  server_template find(map($map_st, "app", "name"), revision: map($map_st, "app", "rev"))
  inputs do {
    'ephemeral_lvm/logical_volume_name' => 'text:ephemeral0',
    'ephemeral_lvm/logical_volume_size' => 'text:100%VG',
    'ephemeral_lvm/mount_point' => 'text:/mnt/ephemeral',
    'ephemeral_lvm/stripe_size' => 'text:512',
    'ephemeral_lvm/volume_group_name' => 'text:vg-data',
    'rs-application_php/app_root' => 'text:/',
    'rs-application_php/application_name' => 'text:default',
    'rs-application_php/bind_network_interface' => 'text:private',
    'rs-application_php/database/host' => "env:DB-"+last(split(@@deployment.href,"/"))+":PRIVATE_IP",
    'rs-application_php/database/password' => 'cred:CAT_MYSQL_APP_PASSWORD',
    'rs-application_php/database/schema' => 'text:app_test',
    'rs-application_php/database/user' => 'cred:CAT_MYSQL_APP_USERNAME',
    'rs-application_php/listen_port' => 'text:8080',
    'rs-application_php/scm/repository' => 'text:git://github.com/rightscale/examples.git',
    'rs-application_php/scm/revision' => 'text:unified_php',
    'rs-application_php/vhost_path' => 'text:/dbread',
    'rs-base/ntp/servers' => 'array:["text:time.rightscale.com","text:ec2-us-east.time.rightscale.com","text:ec2-us-west.time.rightscale.com"]',
    'rs-base/swap/size' => 'text:1',
  } end
  # Server Array Settings
  state "enabled"
  array_type "alert"
  elasticity_params do {
    "bounds" => {
      "min_count"            => 1,
      "max_count"            => 5 # Limited to 5 to avoid deploying too many servers.
    },
    "pacing" => {
      "resize_calm_time"     => 5, 
      "resize_down_by"       => 1,
      "resize_up_by"         => 1
    },
    "alert_specific_params" => {
      "decision_threshold"   => 51,
      "voters_tag_predicate" => "App Server"
    }
  } end
end

## TO-DO: Set up separate security groups for each tier with rules that allow the applicable port(s) only from the IP of the given tier server(s)
resource "sec_group", type: "security_group" do
  name join(["sec_group-",@@deployment.href])
  description "CAT security group."
  cloud map( $map_cloud, $param_location, "cloud" )
end

resource "sec_group_rule_http", type: "security_group_rule" do
  name "CAT HTTP Rule"
  description "Allow HTTP access."
  source_type "cidr_ips"
  security_group @sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "80",
    "end_port" => "80"
  } end
end

resource "sec_group_rule_http8080", type: "security_group_rule" do
  name "CAT HTTP Rule"
  description "Allow HTTP port 8080 access."
  source_type "cidr_ips"
  security_group @sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "8080",
    "end_port" => "8080"
  } end
end

resource "sec_group_rule_mysql", type: "security_group_rule" do
  name "CAT MySQL Rule"
  description "Allow MySQL access over standard port."
  source_type "cidr_ips"
  security_group @sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "3306",
    "end_port" => "3306"
  } end
end

### SSH Key ###
resource "ssh_key", type: "ssh_key" do
  like @resources.ssh_key
end

### Placement Group ###
resource "placement_group", type: "placement_group" do
  like @resources.placement_group
end 

##################
# Permissions    #
##################
permission "import_servertemplates" do
  like $server_templates.import_servertemplates
end

####################
# OPERATIONS       #
####################
operation "launch" do 
  description "Concurrently launch the servers" 
  definition "launch_servers" 
  output_mappings do {
    $site_url => $site_link,
    $lb_status => $lb_status_link,
  } end
end

operation "update_app_code" do
  label "Update Application Code"
  description "Select and install a different repo and branch of code."
  definition "install_appcode"
end

operation "scale_out" do
  label "Scale Out"
  description "Adds (scales out) an application tier server."
  definition "scale_out_array"
end

operation "scale_in" do
  label "Scale In"
  description "Scales in an application tier server."
  definition "scale_in_array"
end

##########################
# DEFINITIONS (i.e. RCL) #
##########################
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
    call server_templates.run_recipe_inputs(@lb_server, "rs-haproxy::collectd", {})
    call server_templates.run_recipe_inputs(@app_server, "rs-application_php::collectd", {})  
    call server_templates.run_recipe_inputs(@db_server, "rs-mysql::collectd", {})   
    
    # Import a test database
    call server_templates.run_recipe_inputs(@db_server, "rs-mysql::dump_import", {})  # applicable inputs were set at launch
    
    # Set up the tags for the load balancer and app servers to find each other.
    call server_templates.run_recipe_inputs(@lb_server, "rs-haproxy::tags", {})
    call server_templates.run_recipe_inputs(@app_server, "rs-application_php::tags", {})  
    
    # Due to the concurrent launch above, it's possible the app server came up before the DB server and wasn't able to connect.
    # So, we re-run the application setup script to force it to connect.
    call server_templates.run_recipe_inputs(@app_server, "rs-application_php::default", {})
  end
    
  # Now that all the servers are good to go, tell the LB to find the app server.
  # This must run after the tagging is complete, so it is done outside the concurrent block above.
  call server_templates.run_recipe_inputs(@lb_server, "rs-haproxy::frontend", {})
    
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
  call run_recipe_inputs(@app_server, "rs-application_php::default", {})
end


# Apply the cost center tag to the server array instance(s)
define apply_costcenter_tag(@server_array) do
  # Get the tags for the first instance in the array
  $tags = rs_cm.tags.by_resource(resource_hrefs: [@server_array.current_instances().href[][0]])
  # Pull out only the tags bit from the response
  $tags_array = $tags[0][0]['tags']

  # Loop through the tags from the existing instance and look for the costcenter tag
  $costcenter_tag = ""
  foreach $tag_item in $tags_array do
    $tag = $tag_item['name']
    if $tag =~ /costcenter:id/
      $costcenter_tag = $tag
    end
  end  

  # Now apply the costcenter tag to all the servers in the array - including the one that was just added as part of the scaling operation
  rs_cm.tags.multi_add(resource_hrefs: @server_array.current_instances().href[], tags: [$costcenter_tag])
end


