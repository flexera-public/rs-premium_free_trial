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
# Deploys a basic 3-Tier LAMP Stack in least expensive environment based on user-specified CPU and RAM requirements.
# 
# FEATURES
# User specifies minimum CPU and RAM requirements and CAT finds the least expensive cloud in which to launch the app.
# User can use a post-launch action to install a different version of the application software from a Git repo.
# User can scale out or scale in application servers.


name 'D) App Stack - Least Expensive Cloud'
rs_ca_ver 20160622
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/best_price_new.png)

Launches a scalable LAMP stack that supports application code updates in least expensive PUBLIC or PRIVATE cloud based on user-specified CPU and RAM."
long_description "Launches a 3-tier LAMP stack in the least expensive environment based on user-specified CPU and RAM requirements.\n
Clouds Supported: <B>AWS, Azure, Google, VMware</B>\n
Pro Tip: Select CPU=1 and RAM=1 to end up in the VMware environment."

import "common/parameters"
import "common/lamp_mappings"



##################
# User inputs    #
##################
parameter "param_cpu" do 
  category "User Inputs"
  label "Minimum Number of vCPUs" 
  type "string" 
  description "Minimum number of vCPUs needed for the application." 
  default "2"
end

parameter "param_ram" do 
  category "User Inputs"
  label "Minimum Amount of RAM" 
  type "string" 
  description "Minimum amount of RAM in GBs needed for the application." 
  default "2"
end

parameter "param_costcenter" do
  like $parameters.param_costcenter
end

parameter "param_appcode" do 
  category "Application Code"
  label "Repository and Branch" 
  type "string" 
  allowed_values "(Yellow) github.com/rightscale/examples:unified_php", "(Blue) github.com/rs-services/rs-premium_free_trial:unified_php_modified" 
  default "(Blue) github.com/rs-services/rs-premium_free_trial:unified_php_modified"
  operations "Update Application Code"
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

output "vmware_note" do
  label "Deployment Note"
  category "Output"
end

output "selected_cloud" do
  label "Selected Cloud" 
  category "Application Cost Info"
  description "Least expensive cloud."
end

output "hourly_app_cost" do
  label "Hourly Application Cost" 
  category "Application Cost Info"
  description "Current hourly rate for the application."
end

output "aws_cloud_output" do
  category "Cloud Cost Info"
  label "AWS Cloud" 
  description "AWS region with least expensive option."
end

output "aws_instance_type_output" do
  category "Cloud Cost Info"
  label "AWS Instance Type" 
  description "AWS least expensive option."
end

output "aws_instance_price_output" do
  category "Cloud Cost Info"
  label "AWS Instance Hourly Rate" 
  description "AWS instance hourly rate."
end

output "google_cloud_output" do
  category "Cloud Cost Info"
  label "Google Cloud" 
  description "Google cloud with least expensive option."
end

output "google_instance_type_output" do
  category "Cloud Cost Info"
  label "Google Instance Type" 
  description "Google least expensive option."
end

output "google_instance_price_output" do
  category "Cloud Cost Info"
  label "Google Instance Hourly Rate" 
  description "Google instance hourly rate."
end

output "azure_cloud_output" do
  category "Cloud Cost Info"
  label "Azure Cloud" 
  description "Azure cloud with least expensive option."
end

output "azure_instance_type_output" do
  category "Cloud Cost Info"
  label "Azure Instance Type" 
  description "Azure least expensive option."
end

output "azure_instance_price_output" do
  category "Cloud Cost Info"
  label "Azure Instance Hourly Rate" 
  description "Azure instance hourly rate."
end

output "vmware_cloud_output" do
  category "Cloud Cost Info"
  label "VMware Cloud" 
  description "VMware cloud with least expensive option."
end

output "vmware_instance_type_output" do
  category "Cloud Cost Info"
  label "VMware Instance Type" 
  description "VMware least expensive option."
end

output "vmware_instance_price_output" do
  category "Cloud Cost Info"
  label "VMware Instance Hourly Rate" 
  description "VMware instance hourly rate."
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
mapping "map_cloud" do {
  "AWS" => {
    "cloud_provider" => "Amazon Web Services",
    "cloud_type" => "amazon",
    "zone" => null, # We don't care which az AWS decides to use.
    "sg" => '@sec_group',  
    "ssh_key" => "@ssh_key",
    "pg" => null,
    "mci_mapping" => "Public",
  },
  "Azure" => {   
    "cloud_provider" => "Microsoft Azure",
    "cloud_type" => "azure",
    "zone" => null,
    "sg" => null, 
    "ssh_key" => null,
    "pg" => "@placement_group",
    "mci_mapping" => "Public",
  },
  "Google" => {
    "cloud_provider" => "Google",
    "cloud_type" => "google",
    "zone" => "needs-a-datacenter", # Google requires a zone to be specified at launch. The zone href will be obtained when it's cheapest instance type and related datacenter is identfied below.
    "sg" => '@sec_group',  
    "ssh_key" => null,
    "pg" => null,
    "mci_mapping" => "Public",
  },
  "VMware" => {
    "cloud_provider" => "VMware",
    "cloud_type" => "vscale",
    "zone" => "VMware_Zone_1", # launches in vSphere require a zone being specified.
    "sg" => null, 
    "ssh_key" => "@ssh_key",
    "pg" => null,
    "mci_mapping" => "VMware",
  }
}
end

# Mapping of which ServerTemplates and Revisions to use for each tier.
mapping "map_st" do   
  like $lamp_mappings.map_st
end

mapping "map_mci" do 
  like $lamp_mappings.map_mci
end

# Mapping of names of the creds to use for the DB-related credential items.
# Allows for easier maintenance down the road if needed.
mapping "map_db_creds" do
  like $lamp_mappings.map_db_creds
end


############################
# RESOURCE DEFINITIONS     #
############################

### Server Declarations ###
resource 'lb_server', type: 'server' do
  name 'Load Balancer'
#  cloud map( $map_cloud, $param_location, "cloud" )
#  datacenter map($map_cloud, $param_location, "zone")
#  instance_type map($map_cloud, $param_location, "instance_type")
#  ssh_key_href map($map_cloud, $param_location, "ssh_key")
#  placement_group_href map($map_cloud, $param_location, "pg")
#  security_group_hrefs map($map_cloud, $param_location, "sg") 
  server_template find(map($map_st, "lb", "name"), revision: map($map_st, "lb", "rev"))
#  multi_cloud_image_href find(map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_name"), revision: map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_rev"))
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

  name 'Database Server'
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
  name 'App Server'
#  cloud map( $map_cloud, $param_location, "cloud" )
#  datacenter map($map_cloud, $param_location, "zone")
#  instance_type map($map_cloud, $param_location, "instance_type")
#  ssh_key_href map($map_cloud, $param_location, "ssh_key")
#  placement_group_href map($map_cloud, $param_location, "pg")
#  security_group_hrefs map($map_cloud, $param_location, "sg") 
#  multi_cloud_image_href find(map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_name"), revision: map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_rev"))
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
    'rs-application_php/database/host' => 'env:Database Server:PRIVATE_IP',
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
#  condition $needsSecurityGroup

  name join(["sec_group-",@@deployment.href])
  description "CAT security group."
#  cloud map( $map_cloud, $param_location, "cloud" )
end

resource "sec_group_rule_http", type: "security_group_rule" do
#  condition $needsSecurityGroup
  
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
#  condition $needsSecurityGroup
  
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
#  condition $needsSecurityGroup
  
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
#  condition $needsSshKey

  name join(["sshkey_", last(split(@@deployment.href,"/"))])
#  cloud map($map_cloud, $param_location, "cloud")
end

### Placement Group ###
resource "placement_group", type: "placement_group" do
#  condition $needsPlacementGroup

  name last(split(@@deployment.href,"/"))
#  cloud map($map_cloud, $param_location, "cloud")
end 

##################
# Permissions    #
##################
permission "import_servertemplates" do
  actions   "rs.import"
  resources "rs.publications"
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
    $vmware_note => $vmware_note_text,  # only gets populated if deployed in VMware
    $selected_cloud => $cheapest_cloud,
    $hourly_app_cost => $app_cost,
    $aws_cloud_output => $aws_cloud,
    $aws_instance_type_output => $aws_instance_type,
    $aws_instance_price_output => $aws_instance_price,
    $google_cloud_output => $google_cloud,
    $google_instance_type_output => $google_instance_type,
    $google_instance_price_output => $google_instance_price,
    $azure_cloud_output=> $azure_cloud,
    $azure_instance_type_output => $azure_instance_type,
    $azure_instance_price_output => $azure_instance_price,
    $vmware_cloud_output=> $vmware_cloud,
    $vmware_instance_type_output => $vmware_instance_type,
    $vmware_instance_price_output => $vmware_instance_price
  } end
end

operation "Update Application Code" do
  description "Select and install a different repo and branch of code."
  definition "install_appcode"
end

operation "Scale Out" do
  description "Adds (scales out) an application tier server."
  definition "scale_out_array"
  output_mappings do {
    $hourly_app_cost => $app_cost
  } end
end

operation "Scale In" do
  description "Scales in an application tier server."
  definition "scale_in_array"
  output_mappings do {
    $hourly_app_cost => $app_cost
  } end
end

##########################
# DEFINITIONS (i.e. RCL) #
##########################
define launch_servers(@lb_server, @app_server, @db_server, @ssh_key, @sec_group, @sec_group_rule_http, @sec_group_rule_http8080, @sec_group_rule_mysql, @placement_group, $map_cloud, $map_st, $map_mci, $map_db_creds, $param_cpu, $param_ram, $param_costcenter)  return @lb_server, @app_server, @db_server, @sec_group, @ssh_key, @placement_group, $param_location, $site_link, $lb_status_link, $vmware_note_text, $cheapest_cloud, $cheapest_instance_type, $app_cost, $aws_cloud, $aws_instance_type, $aws_instance_price, $google_cloud, $google_instance_type, $google_instance_price, $azure_cloud, $azure_instance_type, $azure_instance_price, $vmware_cloud, $vmware_instance_type, $vmware_instance_price do 

  # Find and import the server template - just in case it hasn't been imported to the account already
  call importServerTemplate($map_st)
  
  # Calculate where to launch the system

  # Use the pricing API to get some numbers
  call find_cloud_costs($map_cloud, $param_cpu, $param_ram) retrieve $cloud_costs_hash
  
  call audit_log("cloud costs hash", to_s($cloud_costs_hash))
  
  # Build the cloud cost outputs
  $aws_cloud = $cloud_costs_hash["Amazon Web Services"]["cloud_name"]
  $aws_instance_type = $cloud_costs_hash["Amazon Web Services"]["instance_type"]
  $aws_instance_price = switch($cloud_costs_hash["Amazon Web Services"]["price"] == 10000, "", to_s($cloud_costs_hash["Amazon Web Services"]["price"]))
  $google_cloud = $cloud_costs_hash["Google"]["cloud_name"]
  $google_instance_type = $cloud_costs_hash["Google"]["instance_type"]
  $google_instance_price = switch($cloud_costs_hash["Google"]["price"] == 10000, "", to_s($cloud_costs_hash["Google"]["price"]))
  $azure_cloud = $cloud_costs_hash["Microsoft Azure"]["cloud_name"]
  $azure_instance_type = $cloud_costs_hash["Microsoft Azure"]["instance_type"]
  $azure_instance_price = switch($cloud_costs_hash["Microsoft Azure"]["price"] == 10000, "", to_s($cloud_costs_hash["Microsoft Azure"]["price"]))
  $vmware_cloud = $cloud_costs_hash["VMware"]["cloud_name"]
  $vmware_instance_type = $cloud_costs_hash["VMware"]["instance_type"]
  $vmware_instance_price = switch($cloud_costs_hash["VMware"]["price"] == 10000, "", to_s($cloud_costs_hash["VMware"]["price"]))
    
      
  # Find the least expensive cloud option among the allowed clouds
  $cheapest_cloud = ""
  $cheapest_cost = 1000000
  $cheapest_cloud_href = ""
  $cheapest_instance_type_href = ""
  $cheapest_instance_type = ""
  $cheapest_datacenter_href = ""
  foreach $cloud in keys($cloud_costs_hash) do
    if to_n($cloud_costs_hash[$cloud]["price"]) < $cheapest_cost
      $cheapest_cloud = $cloud
      $cheapest_cloud_href = $cloud_costs_hash[$cloud]["cloud_href"]
      $cheapest_cost = to_n($cloud_costs_hash[$cloud]["price"])
      $cheapest_instance_type = $cloud_costs_hash[$cloud]["instance_type"]
      $cheapest_instance_type_href = $cloud_costs_hash[$cloud]["instance_type_href"]
      $cheapest_datacenter_href = $cloud_costs_hash[$cloud]["datacenter_href"]
    end
  end
  
  call audit_log(join(["Selected Cloud: ", $cheapest_cloud, "; Cloud Href: ",$cheapest_cloud_href]), "")
  
  # Store the hourly cost for future reference
  rs.tags.multi_add(resource_hrefs: [@@deployment.href], tags: [join(["lamp_stack:instancecost=",$cheapest_cost])])

  call audit_log(join(["cheapest cloud: ",$cheapest_cloud]), "")

  foreach $cloud in keys($map_cloud) do
    if $cheapest_cloud == map($map_cloud, $cloud, "cloud_provider")
      $param_location = $cloud
    end
  end
      
  call audit_log(join(["param_location: ",$param_location]), "")
    
  # Provision the resources

  # Create credentials used to access the MySQL database as part of the CAT to make it more portable.
  call createCreds(["CAT_MYSQL_ROOT_PASSWORD","CAT_MYSQL_APP_PASSWORD","CAT_MYSQL_APP_USERNAME"])
    
  # find the MCI to use based on which cloud was selected.
  @multi_cloud_image = find("multi_cloud_images", map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_name"), map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_rev"))
  $multi_cloud_image_href = @multi_cloud_image.href
    
  # modify resources with the cheapest cloud
  $resource_hash = to_object(@ssh_key)
  $resource_hash["fields"]["cloud_href"] = $cheapest_cloud_href
  @ssh_key = $resource_hash
  
  $resource_hash = to_object(@sec_group)
  $resource_hash["fields"]["cloud_href"] = $cheapest_cloud_href
  @sec_group = $resource_hash   
  
  $resource_hash = to_object(@placement_group)
  $resource_hash["fields"]["cloud_href"] = $cheapest_cloud_href
  @placement_group = $resource_hash  
  
  $lb_hash = to_object(@lb_server)
  $lb_hash["fields"]["cloud_href"] = $cheapest_cloud_href
  $lb_hash["fields"]["multi_cloud_image_href"] = $multi_cloud_image_href
  $lb_hash["fields"]["instance_type_href"] = $cheapest_instance_type_href
    
  $webtier_hash = to_object(@app_server)
  $webtier_hash["fields"]["cloud_href"] = $cheapest_cloud_href
  $webtier_hash["fields"]["multi_cloud_image_href"] = $multi_cloud_image_href
  $webtier_hash["fields"]["instance_type_href"] = $cheapest_instance_type_href
    
  $db_hash = to_object(@db_server)
  $db_hash["fields"]["cloud_href"] = $cheapest_cloud_href
  $db_hash["fields"]["multi_cloud_image_href"] = $multi_cloud_image_href
  $db_hash["fields"]["instance_type_href"] = $cheapest_instance_type_href      
    
  if map($map_cloud, $param_location, "zone")   
    $lb_hash["fields"]["datacenter_href"] = $cheapest_datacenter_href
    $webtier_hash["fields"]["datacenter_href"] = $cheapest_datacenter_href
    $db_hash["fields"]["datacenter_href"] = $cheapest_datacenter_href
  end
  
  if map($map_cloud, $param_location, "ssh_key")
    provision(@ssh_key)
    $lb_hash["fields"]["ssh_key_href"] = @ssh_key.href
    $webtier_hash["fields"]["ssh_key_href"] = @ssh_key.href
    $db_hash["fields"]["ssh_key_href"] = @ssh_key.href
  end
  
  if map($map_cloud, $param_location, "pg") 
    provision(@placement_group)
    $lb_hash["fields"]["placement_group_href"] = @placement_group.href
    $webtier_hash["fields"]["placement_group_href"] = @placement_group.href
    $db_hash["fields"]["placement_group_href"] = @placement_group.href
  end
  
  if map($map_cloud, $param_location, "sg")
    provision(@sec_group_rule_http)
    provision(@sec_group_rule_http8080)
    provision(@sec_group_rule_mysql)
    $lb_hash["fields"]["security_group_hrefs"] = [@sec_group.href]
    $webtier_hash["fields"]["security_group_hrefs"] = [@sec_group.href]
    $db_hash["fields"]["security_group_hrefs"] = [@sec_group.href]
  end
  
  @lb_server = $lb_hash  
  @app_server = $webtier_hash
  @db_server = $db_hash
  
  # Launch the servers concurrently
  concurrent return  @lb_server, @app_server, @db_server do 
    sub task_name:"Launch DB" do
      task_label("Launching DB")
      $db_retries = 0 
      sub on_error: handle_retries($db_retries) do
        $db_retries = $db_retries + 1
        provision(@db_server)
      end
    end
    sub task_name:"Launch LB" do
      task_label("Launching LB")
      $lb_retries = 0 
      sub on_error: handle_retries($lb_retries) do
        $lb_retries = $lb_retries + 1
        provision(@lb_server)
      end
    end
    
    sub task_name:"Launch Application Tier" do
      task_label("Launching Application Tier")
      $apptier_retries = 0 
      sub on_error: handle_retries($apptier_retries) do
        $apptier_retries = $apptier_retries + 1
        provision(@app_server)
      end
    end
  end
  
  concurrent do  
    # Enable monitoring for server-specific application software
    call run_recipe_inputs(@lb_server, "rs-haproxy::collectd", {})
    call run_recipe_inputs(@app_server, "rs-application_php::collectd", {})  
    call run_recipe_inputs(@db_server, "rs-mysql::collectd", {})   
    
    # Import a test database
    call run_recipe_inputs(@db_server, "rs-mysql::dump_import", {})  # applicable inputs were set at launch
    
    # Set up the tags for the load balancer and app servers to find each other.
    call run_recipe_inputs(@lb_server, "rs-haproxy::tags", {})
    call run_recipe_inputs(@app_server, "rs-application_php::tags", {})  
    
    # Due to the concurrent launch above, it's possible the app server came up before the DB server and wasn't able to connect.
    # So, we re-run the application setup script to force it to connect.
    call run_recipe_inputs(@app_server, "rs-application_php::default", {})
  end
    
  # Now that all the servers are good to go, tell the LB to find the app server.
  # This must run after the tagging is complete, so it is done outside the concurrent block above.
  call run_recipe_inputs(@lb_server, "rs-haproxy::frontend", {})
    
  # If deployed in Azure one needs to provide the port mapping that Azure uses.
  if $param_location == "Azure"
     @bindings = rs.clouds.get(href: @lb_server.current_instance().cloud().href).ip_address_bindings(filter: ["instance_href==" + @lb_server.current_instance().href])
     @binding = select(@bindings, {"private_port":80})
     $server_addr = join([to_s(@lb_server.current_instance().public_ip_addresses[0]), ":", @binding.public_port])
  else
    if $param_location == "VMware"  # Use private IP for VMware envs
        # Wait for the server to get the IP address we're looking for.
        while equals?(@lb_server.current_instance().private_ip_addresses[0], null) do
          sleep(10)
        end
        $server_addr =  to_s(@lb_server.current_instance().private_ip_addresses[0])
        $vmware_note_text = "Your CloudApp was deployed in a VMware environment on a private network and so is not directly accessible."
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
    
  call calc_app_cost(@app_server) retrieve $app_cost
  
  # Now tag the servers with the selected project cost center ID.
  $tags=[join(["costcenter:id=",$param_costcenter])]
  rs.tags.multi_add(resource_hrefs: @@deployment.servers().current_instance().href[], tags: $tags)
  rs.tags.multi_add(resource_hrefs: @@deployment.server_arrays().current_instances().href[], tags: $tags)

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

# Scale out (add) server
define scale_out_array(@app_server, @lb_server) return $app_cost do
  task_label("Scale out application server.")
  @task = @app_server.launch(inputs: {})

  $wake_condition = "/^(operational|stranded|stranded in booting|stopped|terminated|inactive|error)$/"
  sleep_until all?(@app_server.current_instances().state[], $wake_condition)
  if !all?(@app_server.current_instances().state[], "operational")
    raise "Some instances failed to start"    
  end
  
  # Now execute post launch scripts to finish setting up the server.
  concurrent do
    call run_recipe_inputs(@app_server, "rs-application_php::collectd", {})  
    call run_recipe_inputs(@app_server, "rs-application_php::tags", {})  
  end
  
  # Tell the load balancer to find the new app server
  call run_recipe_inputs(@lb_server, "rs-haproxy::frontend", {})
    
  call calc_app_cost(@app_server) retrieve $app_cost

  call apply_costcenter_tag(@app_server)

end

# Apply the cost center tag to the server array instance(s)
define apply_costcenter_tag(@server_array) do
  # Get the tags for the first instance in the array
  $tags = rs.tags.by_resource(resource_hrefs: [@server_array.current_instances().href[][0]])
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
  rs.tags.multi_add(resource_hrefs: @server_array.current_instances().href[], tags: [$costcenter_tag])
end

# Scale in (remove) server
define scale_in_array(@app_server) return $app_cost do
  task_label("Scale in web server array.")

  @terminable_servers = select(@app_server.current_instances(), {"state":"/^(operational|stranded)/"})
  if size(@terminable_servers) > 0 
    # Terminate the oldest instance in the array.
    @server_to_terminate = first(@terminable_servers)
    # Have it tell the load balancer of it's impending demise
    call run_recipe_inputs(@server_to_terminate, "rs-application_php::application_backend_detached", {})
    # Cause that much anticipated demise
    @server_to_terminate.terminate()
    # Wait for the server to be no longer of this mortal coil
    sleep_until(@server_to_terminate.state != "operational" )
  else
    rs.audit_entries.create(audit_entry: {auditee_href: @app_server.href, summary: "Scale In: No terminable server currently found in the server array"})
  end
  
  call calc_app_cost(@app_server) retrieve $app_cost

end

####################
# Helper Functions #
####################
# Checks if the account supports the selected cloud
define checkCloudSupport($cloud_name, $param_location) do
  # Gather up the list of clouds supported in this account.
  @clouds = rs.clouds.get()
  $supportedClouds = @clouds.name[] # an array of the names of the supported clouds
  
  # Check if the selected/mapped cloud is in the list and yell if not
  if logic_not(contains?($supportedClouds, [$cloud_name]))
    raise "Your trial account does not support the "+$param_location+" cloud. Contact RightScale for more information on how to enable access to that cloud."
  end
end
  
# Imports the server templates found in the given map.
# It assumes a "name" and "rev" mapping
define importServerTemplate($stmap) do
  foreach $st in keys($stmap) do
    $server_template_name = map($stmap, $st, "name")
    $server_template_rev = map($stmap, $st, "rev")
    @pub_st=rs.publications.index(filter: ["name=="+$server_template_name, "revision=="+$server_template_rev])
    @pub_st.import()
  end
end

# Creates CREDENTIAL objects in Cloud Management for each of the named items in the given array.
define createCreds($credname_array) do
  foreach $cred_name in $credname_array do
    @cred = rs.credentials.get(filter: [ join(["name==",$cred_name]) ])
    if empty?(@cred) 
      $cred_value = join(split(uuid(), "-"))[0..14] # max of 16 characters for mysql username and we're adding a letter next.
      $cred_value = "a" + $cred_value # add an alpha to the beginning of the value - just in case.
      @task=rs.credentials.create({"name":$cred_name, "value": $cred_value})
    end
  end
end

# Helper functions
define handle_retries($attempts) do
  if $attempts < 3
    $_error_behavior = "retry"
    sleep(60)
  else
    $_error_behavior = "skip"
  end
end

define run_recipe_inputs(@target, $recipe_name, $recipe_inputs) do
  $target_type = type(@target)
  if equals?($target_type, "rs.server_arrays") 
    
    @running_servers = select(@target.current_instances(), {"state":"operational"})
    @tasks = @running_servers.run_executable(recipe_name: $recipe_name, inputs: $recipe_inputs)
    sleep_until(all?(@tasks.summary[], "/^(completed|failed)/"))
    if any?(@tasks.summary[], "/^failed/")
      raise "Failed to run " + $right_script_href + " on one or more instances"
    end
    
  else # server or instance
    
    if equals?($target_type, "rs.instances")
      @exec_target=@target # target is already an instance type so we're good to go
    else
      @exec_target=@target.current_instance() # target is a server and so we need to link to the instance
    end
    
    # Run the recipe against the instance
    @task = @exec_target.run_executable(recipe_name: $recipe_name, inputs: $recipe_inputs)
    sleep_until(@task.summary =~ "^(completed|failed)")
    if @task.summary =~ "failed"
      raise "Failed to run " + $recipe_name
    end
    
  end
end

# Calculate the cost of using the different clouds found in the $map_cloud mapping
define find_cloud_costs($map_cloud, $cpu_count, $ram_count) return $cloud_costs_hash do
  
  $cloud_costs_hash = {}
  $supported_instance_types_hash = {}
  # Seed the cloud info
  $cloud_info = {
    "price": 10000,
    "cloud_name": "",
    "cloud_href": "",
    "instance_type": "",
    "instance_type_href": "",
    "datacenter_name": "",
    "datacenter_href": ""
  }
  $cloud_href_filter = []
  $cloud_provider_filter = []
  foreach $cloud in keys($map_cloud) do
    
    $cloud_vendor_name = map($map_cloud, $cloud, "cloud_provider")

    # Seed the cloud hash 
    $cloud_costs_hash[$cloud_vendor_name] = $cloud_info
    # add in the datacenter_name if it's in the cloud mapping
    $cloud_costs_hash[$cloud_vendor_name]["datacenter_name"] = map($map_cloud, $cloud, "zone")
 
    # Build a cloud provider filter for the api call below.
    # No longer needed since we build a filter of clouds/regions.
#      $cloud_provider_filter << $cloud_vendor_name
    
    # Build up a list of cloud hrefs for the pricing filter below
    $cloud_href_array = rs.clouds.get(filter: [ join(["cloud_type==",map($map_cloud, $cloud, "cloud_type")]) ]).href[]
    $cloud_href_filter = $cloud_href_filter + $cloud_href_array
  end
  
  call audit_log("seeded cloud_costs_hash:", to_s($cloud_costs_hash))

   # Build an array of cpu counts for the pricing API filter
   $numcpu = to_n($param_cpu)
   $maxcpu = $numcpu + 1 # try one cpu bigger as well in the search.
   $cpu_count_array = [$numcpu, $maxcpu]

   # pricing filters
   $filter = {
#     public_cloud_vendor_name: $cloud_provider_filter,  
     cloud_href: $cloud_href_filter,
     cpu_count: $cpu_count_array,
     account_href: [null],  # this returns the standard on-demand pricing
     resource_type: ["instance"],
     purchase_option_type: ["on_demand_instance"],
     platform: ["Linux/UNIX"],
     platform_version: [null]  # This finds vanilla "free" linux instance types - avoiding for-fee variants like Redhat or Suse
    }
      
   call audit_log(join(["pricing filter: "]), to_s($filter))
           
   # Get an array of price hashes for the given filters
   $response = http_request(
     verb: "get",
     host: "pricing.rightscale.com",
     https: true,
     href: "/api/prices",
     headers: { "X_API_VERSION": "1.0", "Content-Type": "application/json" },
     query_strings: {
       filter: to_json($filter) # For Praxis-based APIs (e.g. the pricing API) one needs to to_json() the query string values to avoid URL encoding of the null value in the filter.
       }
     )
   
   $price_hash_array = $response["body"]
     
   call audit_log(join(["price_hash_array size: ", size($price_hash_array)]), "")
     
   # Now we need to find the best pricing info for the vanilla Linux/Unix platform
   # with the minimum cpu and ram for the given cloud
   $cloud_best_price = 100000
   foreach $price_hash in $price_hash_array do
     
     # Need to figure out which cloud vendor we have here
     if contains?(keys($price_hash["priceable_resource"]), ["public_cloud_vendor_name"])
        $found_cloud_vendor = $price_hash["priceable_resource"]["public_cloud_vendor_name"]
     else
        $found_cloud_vendor = "VMware"
     end
         
#     call audit_log(join(["found vendor: ", $found_cloud_vendor]), "")

     
     # We are ok with any Google or Azure type.
     # But we need to avoid looking at AWS EBS-backed instance types since we currently use an MCI that requires ephemeral disk based instance types in AWS.
     # Also the Google price_hash does not have a local_disk_size attribute so we can't just look at that.
     # Hence a multidimensional condition test
     if logic_or(logic_or(logic_or($found_cloud_vendor == "Google", $found_cloud_vendor == "Microsoft Azure"), $found_cloud_vendor == "VMware"), logic_and($found_cloud_vendor == "Amazon Web Services", to_s($price_hash["priceable_resource"]["local_disk_size"]) != "0.0"))
#       call audit_log(join(["found a valid price_hash for ", $found_cloud_vendor]), to_s($price_hash))

       $purchase_options = keys($price_hash["purchase_option"])
         
       # Check the RAM offering for the given instance type to make sure it meets the minimum required by the user
       # Although there is a memory filter in the pricing API, this is easier than guessing what possible memory configs are available by the differen cloud providers.
       $memory = to_n($price_hash["priceable_resource"]["memory"])
       if $memory >= to_n($ram_count)
         # then it's a contender
       
           # There may be more than one usage_charge elements in the returned array. So find one that is NOT an option since this is the base price we'll be using
           $price = ""
           foreach $usage_charge in $price_hash["usage_charges"] do
              $price = $usage_charge["price"]
#              call audit_log(join(["Found price for ", $found_cloud_vendor, "; price: ", $price]), to_s($price_hash))
           end
           
           # Is it cheapest so far?
           if to_n($price) < $cloud_costs_hash[$found_cloud_vendor]["price"]
             
             # Even if it's cheaper, make sure it's a supported instance type 
             call checkInstanceType($price_hash["purchase_option"]["cloud_href"], $price_hash["priceable_resource"]["name"], $supported_instance_types_hash) retrieve $supported_instance_types_hash, $usableInstanceType
             if $usableInstanceType # the pricing API returned an instance type that is supported for the account
             
               $cloud_best_price = to_n($price)
               $cloud_href = $price_hash["purchase_option"]["cloud_href"]
               $instance_type = $price_hash["priceable_resource"]["name"]
               @cloud = rs.clouds.get(href: $cloud_href)
               $instance_type_href = @cloud.instance_types(filter: [join(["name==",$instance_type])]).href
               if contains?($purchase_options, ["datacenter_name"])  # then set the datacenter with that provided in the pricing info
                  $datacenter_name = $price_hash["purchase_option"]["datacenter_name"]
                  $datacenter_href = @cloud.datacenters(filter: [join(["name==",$datacenter_name])]).href
               elsif $cloud_costs_hash[$found_cloud_vendor]["datacenter_name"]  # then use the datacenter we set in the cloud map
                  $datacenter_name = $cloud_costs_hash[$found_cloud_vendor]["datacenter_name"]
                  $datacenter_href = @cloud.datacenters(filter: [join(["name==",$datacenter_name])]).href
               end
               $cloud_info = {
                 "price": $cloud_best_price,
                 "cloud_name": @cloud.name,
                 "cloud_href": $cloud_href,
                 "instance_type": $instance_type,
                 "instance_type_href": $instance_type_href,
                 "datacenter_href": $datacenter_href
               }
               $cloud_costs_hash[$found_cloud_vendor] = $cloud_info
             end # usable instance type check
           end # price comparison
       end # RAM check
     end # EBS-backed instance type test
   end # price_hash loop
end

# Calculate the application cost
define calc_app_cost(@web_tier) return $app_cost do
  
  # assume we aren't doing cost data (e.g. if user explicitly selected a cloud the CAT doesn't do costing in that case)
  $app_cost = null
  $instance_cost = null
  
  # Get the hourly cost that we may have stored as a tag
  $tags = rs.tags.by_resource(resource_hrefs: [@@deployment.href])
  $tag_array = $tags[0][0]['tags']
  $cost_tagged = false
  foreach $tag_item in $tag_array do
    if $tag_item['name'] =~ /instancecost/
      $tag = $tag_item['name']
      $instance_cost = to_n(split($tag, "=")[1])
    end
  end
  
  if $instance_cost  # Then we have instance cost informatin and so can calculate application cost
    # see how many web server instances there are
    @web_servers = select(@web_tier.current_instances(), {"state":"/^(operational|stranded)/"})
    $num_web_servers = size(@web_servers)
    # Ruby floating point arithmetic can cause strange results. Google it.
    # So to deal with it, we turn everything into an integer when doing the multiplications and then bring it back down to dollars and cents at the end.
    # We multiply/divide by 1000 to account for some of the pricing out there that goes to half-cents.
    $calculated_app_cost = (($num_web_servers + 2) * ($instance_cost * 1000))/1000  
    $app_cost = to_s($calculated_app_cost)
  end
  
end

# Checks instance type to see if it is supported by the given, attached cloud
define checkInstanceType($cloud_href, $instance_type, $supported_instance_types_hash) return $supported_instance_types_hash, $usableInstanceType do
  
  # add instance types for the cloud_href if not already in the instance types hash
  if logic_not($supported_instance_types_hash[$cloud_href])

    @cloud=rs.clouds.get(href: $cloud_href)
    @instance_types = @cloud.instance_types().get()
    $instance_type_names=@instance_types.name[]
    $supported_instance_types_hash[$cloud_href] = $instance_type_names
    
#    call audit_log(join(["Gathered instance types for cloud, ", $cloud_href]), to_s($instance_type_names))
  end
  
  # Check if the instance type found in the pricing API is a supported instance type
  $usableInstanceType = contains?($supported_instance_types_hash[$cloud_href], [$instance_type])
  
#  if logic_not($usableInstanceType)
#    call audit_log(join(["Found unsupported instance type, ", to_s($instance_type), " in cloud, ", to_s($cloud_href)]), "")
#  end
end


define audit_log($summary, $details) do
  rs.audit_entries.create(
    notify: "None",
    audit_entry: {
      auditee_href: @@deployment,
      summary: $summary,
      detail: $details
    }
  )
end


