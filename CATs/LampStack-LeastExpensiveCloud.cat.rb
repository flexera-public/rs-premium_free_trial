#Copyright 2015 RightScale
#x
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
rs_ca_ver 20161221
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/best_price_new.png)

Launches a scalable LAMP stack that supports application code updates in least expensive PUBLIC or PRIVATE cloud based on user-specified CPU and RAM."
long_description "Launches a 3-tier LAMP stack in the least expensive environment based on user-specified CPU and RAM requirements.\n
Clouds Supported: <B>AWS, Azure, Google, VMware</B>\n
Pro Tip: Select CPU=1 and RAM=1 to end up in the VMware environment."

import "pft/parameters"
import "pft/rl10/lamp_parameters", as: "lamp_parameters"
import "pft/rl10/lamp_outputs", as: "lamp_outputs"
import "pft/mappings"
import "pft/rl10/lamp_mappings", as: "lamp_mappings"
import "pft/conditions"
import "pft/resources"
import "pft/rl10/lamp_resources", as: "lamp_resources"
import "pft/server_templates_utilities"
import "pft/server_array_utilities"
import "pft/rl10/lamp_utilities", as: "lamp_utilities"
import "pft/permissions"
import "pft/err_utilities"
import "pft/creds_utilities"
 
##################
# Permissions    #
##################
permission "pft_general_permissions" do
  like $permissions.pft_general_permissions
end

##################
# User inputs    #
##################
parameter "param_cpu" do 
  category "User Inputs"
  label "Minimum Number of vCPUs" 
  type "number" 
  description "Minimum number of vCPUs needed for the application." 
  allowed_values 2, 4, 8
  default 2
end

parameter "param_ram" do 
  category "User Inputs"
  label "Minimum Amount of RAM" 
  type "number"
  description "Minimum amount of RAM in GBs needed for the application." 
  min_value 2 # The Chef server is not happy with less than 2GB of RAM.
  default 2
end

parameter "param_costcenter" do
  like $parameters.param_costcenter
end

parameter "param_chef_password" do
  like $lamp_parameters.param_chef_password
  operations "launch"
end

parameter "param_appcode" do 
  category "Application Code"
  label "Repository and Branch" 
  type "string" 
  allowed_values "(Yellow) github.com/rightscale/examples:unified_php", "(Blue) github.com/rs-services/rs-premium_free_trial:unified_php_modified" 
  default "(Blue) github.com/rs-services/rs-premium_free_trial:unified_php_modified"
  operations "update_app_code"
end

################################
# Outputs returned to the user #
################################
output "site_url" do
  like $lamp_outputs.site_url
end

output "lb_status" do
  like $lamp_outputs.lb_status
end

output "app1_github_link" do
  like $lamp_outputs.app1_github_link
end

output "app2_github_link" do
  like $lamp_outputs.app2_github_link
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
    "network" => null,
    "subnet" => null,
    "mci_mapping" => "Public",
  },
  "Azure" => {   
    "cloud_provider" => "Microsoft Azure",
    "cloud_type" => "azure_v2",
    "zone" => null,
    "sg" => null, 
    "ssh_key" => null,
    "pg" => null,
    "network" => "pft_arm_network",
    "subnet" => "default",
    "mci_mapping" => "Public", 
  },
  "Google" => {
    "cloud_provider" => "Google",
    "cloud_type" => "google",
    "zone" => "needs-a-datacenter", # Google requires a zone to be specified at launch. The zone href will be obtained when it's cheapest instance type and related datacenter is identfied below.
    "sg" => '@sec_group',  
    "ssh_key" => null,
    "pg" => null,
    "network" => null,
    "subnet" => null,
    "mci_mapping" => "Public",
  },
  "VMware" => {  
    "cloud_provider" => "VMware",
    "cloud_type" => "vscale",
    "zone" => "VMware_Zone_1", # launches in vSphere require a zone being specified.
    "sg" => null, 
    "ssh_key" => "@ssh_key",
    "pg" => null,
    "network" => null,
    "subnet" => null,
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

mapping "map_nulls" do {
  "place_holder" => {
    "null_value" => null
  }
} end
  


############################
# RESOURCE DEFINITIONS     #
############################

### Server Declarations ###
resource 'chef_server', type: 'server' do
  like @lamp_resources.chef_server
  # The following attributes are configured in RCL below once we know which cloud we are using.
  # So we overwrite some placeholder values for now.
  cloud map($map_nulls, "place_holder", "null_value")
  datacenter map($map_nulls, "place_holder", "null_value")
  instance_type map($map_nulls, "place_holder", "null_value")
  ssh_key_href map($map_nulls, "place_holder", "null_value")
  placement_group_href map($map_nulls, "place_holder", "null_value")
  security_group_hrefs map($map_nulls, "place_holder", "null_value")
  multi_cloud_image_href map($map_nulls, "place_holder", "null_value")
  network_href map($map_nulls, "place_holder", "null_value")
  subnet_hrefs [map($map_nulls, "place_holder", "null_value")]
end

resource 'lb_server', type: 'server' do
  like @lamp_resources.lb_server
  # The following attributes are configured in RCL below once we know which cloud we are using.
  # So we overwrite some placeholder values for now.
  cloud map($map_nulls, "place_holder", "null_value")
  datacenter map($map_nulls, "place_holder", "null_value")
  instance_type map($map_nulls, "place_holder", "null_value")
  ssh_key_href map($map_nulls, "place_holder", "null_value")
  placement_group_href map($map_nulls, "place_holder", "null_value")
  security_group_hrefs map($map_nulls, "place_holder", "null_value")
  multi_cloud_image_href map($map_nulls, "place_holder", "null_value")
  network_href map($map_nulls, "place_holder", "null_value")
  subnet_hrefs [map($map_nulls, "place_holder", "null_value")]
end

resource 'db_server', type: 'server' do
  like @lamp_resources.db_server
  # The following attributes are configured in RCL below once we know which cloud we are using.
  # So we overwrite some placeholder values for now.
  cloud map($map_nulls, "place_holder", "null_value")
  datacenter map($map_nulls, "place_holder", "null_value")
  instance_type map($map_nulls, "place_holder", "null_value")
  ssh_key_href map($map_nulls, "place_holder", "null_value")
  placement_group_href map($map_nulls, "place_holder", "null_value")
  security_group_hrefs map($map_nulls, "place_holder", "null_value")
  multi_cloud_image_href map($map_nulls, "place_holder", "null_value")
  network_href map($map_nulls, "place_holder", "null_value")
  subnet_hrefs [map($map_nulls, "place_holder", "null_value")]
end

resource 'app_server', type: 'server_array' do
  like @lamp_resources.app_server
  # The following attributes are configured in RCL below once we know which cloud we are using.
  # So we overwrite some placeholder values for now.
  cloud map($map_nulls, "place_holder", "null_value")
  datacenter map($map_nulls, "place_holder", "null_value")
  instance_type map($map_nulls, "place_holder", "null_value")
  ssh_key_href map($map_nulls, "place_holder", "null_value")
  placement_group_href map($map_nulls, "place_holder", "null_value")
  security_group_hrefs map($map_nulls, "place_holder", "null_value")
  multi_cloud_image_href map($map_nulls, "place_holder", "null_value")
  network_href map($map_nulls, "place_holder", "null_value")
  subnet_hrefs [map($map_nulls, "place_holder", "null_value")]
end

## TO-DO: Set up separate security groups for each tier with rules that allow the applicable port(s) only from the IP of the given tier server(s)
resource "sec_group", type: "security_group" do
  like @lamp_resources.sec_group
  cloud map($map_nulls, "place_holder", "null_value") # placeholder until we know which cloud
end

resource "sec_group_rule_http", type: "security_group_rule" do
  like @lamp_resources.sec_group_rule_http
end

resource "sec_group_rule_https", type: "security_group_rule" do
  like @lamp_resources.sec_group_rule_https
end

resource "sec_group_rule_ssh", type: "security_group_rule" do
  like @lamp_resources.sec_group_rule_ssh
end

resource "sec_group_rule_http8080", type: "security_group_rule" do
  like @lamp_resources.sec_group_rule_http8080
end

resource "sec_group_rule_mysql", type: "security_group_rule" do
  like @lamp_resources.sec_group_rule_mysql
end

### SSH Key ###
resource "ssh_key", type: "ssh_key" do
  like @resources.ssh_key
  cloud map($map_nulls, "place_holder", "null_value") # placeholder until we know which cloud
end

### Placement Group ###
resource "placement_group", type: "placement_group" do
  like @resources.placement_group
  cloud map($map_nulls, "place_holder", "null_value") # placeholder until we know which cloud
end 

##################
# Permissions    #
##################
permission "import_servertemplates" do
  like $server_templates_utilities.import_servertemplates
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

operation "terminate" do
  description "Clean up a few unique items"
  definition "lamp_utilities.delete_resources"
end

operation "update_app_code" do
  label "Update Application Code"
  description "Select and install a different repo and branch of code."
  definition "lamp_utilities.install_appcode"
end

operation "scale_out_app" do
  label "Scale Out"
  description "Adds (scales out) an application tier server."
  definition "scale_out"
  output_mappings do {
    $hourly_app_cost => $app_cost
  } end
end

operation "scale_in_app" do
  label "Scale In"
  description "Scales in an application tier server."
  definition "scale_in"
  output_mappings do {
    $hourly_app_cost => $app_cost
  } end
end

##########################
# DEFINITIONS (i.e. RCL) #
##########################
define launch_servers(@chef_server, @lb_server, @app_server, @db_server, @ssh_key, @sec_group, @sec_group_rule_ssh, @sec_group_rule_http, @sec_group_rule_https, @sec_group_rule_http8080, @sec_group_rule_mysql, @placement_group, $map_cloud, $map_st, $map_mci, $map_db_creds, $param_cpu, $param_ram, $param_costcenter)  return @chef_server, @lb_server, @app_server, @db_server, @sec_group, @ssh_key, @placement_group, $param_location, $site_link, $lb_status_link, $vmware_note_text, $cheapest_cloud, $cheapest_instance_type, $app_cost, $aws_cloud, $aws_instance_type, $aws_instance_price, $google_cloud, $google_instance_type, $google_instance_price, $azure_cloud, $azure_instance_type, $azure_instance_price, $vmware_cloud, $vmware_instance_type, $vmware_instance_price do 

  # Calculate where to launch the system

  # Use the pricing API to get some numbers
  call find_cloud_costs($map_cloud, $param_cpu, $param_ram) retrieve $cloud_costs_hash
  
  call err_utilities.log("cloud costs hash", to_s($cloud_costs_hash))
  
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
  
  call err_utilities.log(join(["Selected Cloud: ", $cheapest_cloud, "; Cloud Href: ",$cheapest_cloud_href]), "")
  
  # Store the hourly cost for future reference
  rs_cm.tags.multi_add(resource_hrefs: [@@deployment.href], tags: [join(["lamp_stack:instancecost=",$cheapest_cost])])

  call err_utilities.log(join(["cheapest cloud: ",$cheapest_cloud]), "")

  foreach $cloud in keys($map_cloud) do
    if $cheapest_cloud == map($map_cloud, $cloud, "cloud_provider")
      $param_location = $cloud
    end
  end
      
  call err_utilities.log(join(["param_location: ",$param_location]), "")
    
  # Finish configuring the resource declarations so they are ready for launch
    
  # find the MCI to use based on which cloud was selected.
  @multi_cloud_image = find("multi_cloud_images", map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_name"), map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_rev"))
  $multi_cloud_image_href = @multi_cloud_image.href
      
  # modify resources with the cheapest cloud
  $update_hash = { "cloud_href": $cheapest_cloud_href }
  call modify_resource_definition(@ssh_key, $update_hash) retrieve @ssh_key
  call modify_resource_definition(@sec_group, $update_hash) retrieve @sec_group
  call modify_resource_definition(@placement_group, $update_hash) retrieve @placement_group
  
  $update_hash = { "multi_cloud_image_href":$multi_cloud_image_href, "instance_type_href":$cheapest_instance_type_href} + $update_hash 
  call modify_resource_definition(@chef_server, $update_hash) retrieve @chef_server
  call modify_resource_definition(@lb_server, $update_hash) retrieve @lb_server
  call modify_resource_definition(@app_server, $update_hash) retrieve @app_server
  call modify_resource_definition(@db_server, $update_hash) retrieve @db_server
   
  if map($map_cloud, $param_location, "zone")  
    $update_hash = { "datacenter_href":$cheapest_datacenter_href }
    call modify_resource_definition(@chef_server, $update_hash) retrieve @chef_server
    call modify_resource_definition(@lb_server, $update_hash) retrieve @lb_server
    call modify_resource_definition(@app_server, $update_hash) retrieve @app_server
    call modify_resource_definition(@db_server, $update_hash) retrieve @db_server
  end
  
  $network_href = ""
  if map($map_cloud, $param_location, "network")  
    @network = find("networks", { name: map($map_cloud, $param_location, "network"), cloud_href: $cheapest_cloud_href })
    $network_href = @network.href
     
    $update_hash = { "network_href":$network_href }
    call modify_resource_definition(@chef_server, $update_hash) retrieve @chef_server
    call modify_resource_definition(@lb_server, $update_hash) retrieve @lb_server
    call modify_resource_definition(@app_server, $update_hash) retrieve @app_server
    call modify_resource_definition(@db_server, $update_hash) retrieve @db_server
  end
  
  if map($map_cloud, $param_location, "subnet")       
    @subnet = find("subnets", { name:map($map_cloud, $param_location, "subnet"),  network_href: $network_href })
    $subnet_href = @subnet.href[]

    $update_hash = { "subnet_hrefs":$subnet_href }
    call modify_resource_definition(@chef_server, $update_hash) retrieve @chef_server
    call modify_resource_definition(@lb_server, $update_hash) retrieve @lb_server
    call modify_resource_definition(@app_server, $update_hash) retrieve @app_server
    call modify_resource_definition(@db_server, $update_hash) retrieve @db_server
  end
  
  if map($map_cloud, $param_location, "ssh_key")
    provision(@ssh_key)
    
    $update_hash = { "ssh_key_href":@ssh_key.href }
    call modify_resource_definition(@chef_server, $update_hash) retrieve @chef_server
    call modify_resource_definition(@lb_server, $update_hash) retrieve @lb_server
    call modify_resource_definition(@app_server, $update_hash) retrieve @app_server
    call modify_resource_definition(@db_server, $update_hash) retrieve @db_server
  end
  
  if map($map_cloud, $param_location, "pg") 
    provision(@placement_group)
    
    $update_hash = { "placement_group_href":@placement_group.href }
    call modify_resource_definition(@chef_server, $update_hash) retrieve @chef_server
    call modify_resource_definition(@lb_server, $update_hash) retrieve @lb_server
    call modify_resource_definition(@app_server, $update_hash) retrieve @app_server
    call modify_resource_definition(@db_server, $update_hash) retrieve @db_server
  end
  
  if map($map_cloud, $param_location, "sg")
    provision(@sec_group_rule_http)
    provision(@sec_group_rule_http8080)
    provision(@sec_group_rule_mysql)
    provision(@sec_group_rule_ssh)
    provision(@sec_group_rule_https)
    
    $update_hash = { "security_group_hrefs":[@sec_group.href] }
    call modify_resource_definition(@chef_server, $update_hash) retrieve @chef_server
    call modify_resource_definition(@lb_server, $update_hash) retrieve @lb_server
    call modify_resource_definition(@app_server, $update_hash) retrieve @app_server
    call modify_resource_definition(@db_server, $update_hash) retrieve @db_server
  end
  
#  call err_utilities.log("chef_sever object hash", to_s(to_object(@chef_server)))
    
  # At this point we have the server declarations updated with the necessary values from the least expensive cloud search.
  # We've also already provisioned the security groups and ssh keys, etc if needed.
  # So now we are ready to provision the servers. To do so we will use the launch_servers definition for the LAMP stack.
  # But we need to work around a couple of things. First of all the security groups and stuff are already provisioned, so we pass "false" for the parameters that would cause launch_servers() to try and (re)provision them.
  # And similarly, we retrieve fake values for these resources so we don't mess up the originals.
  # We also don't have the standard conditions around $inAzure and $inVMware so we evaluate things and pass those results.
  call creds_utilities.createCreds(["CAT_MYSQL_ROOT_PASSWORD","CAT_MYSQL_APP_PASSWORD","CAT_MYSQL_APP_USERNAME"])
  call lamp_utilities.launch_resources(@chef_server, @lb_server, @app_server, @db_server, @ssh_key, @sec_group, @sec_group_rule_ssh, @sec_group_rule_http, @sec_group_rule_https, @sec_group_rule_http8080, @sec_group_rule_mysql, @placement_group, $param_costcenter, false, equals?($param_location,"VMware"), false, false, false, $cheapest_cloud)  retrieve @chef_serer, @lb_server, @app_server, @db_server, @sec_group_fake, @ssh_key_fake, @placement_group_fake, $site_link, $lb_status_link 

  call calc_app_cost(@app_server) retrieve $app_cost
  
end 

# Modify the resource's declaration with the applicable bits given in the $update_hash
define modify_resource_definition(@resource, $update_hash) return @resource do
  $resource_hash = to_object(@resource)
  foreach $field in keys($update_hash) do
    $resource_hash["fields"][$field] = $update_hash[$field]
  end
  @resource = $resource_hash
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
    $cloud_href_array = rs_cm.clouds.get(filter: [ join(["cloud_type==",map($map_cloud, $cloud, "cloud_type")]) ]).href[]
    $cloud_href_filter = $cloud_href_filter + $cloud_href_array
  end
  
  ### FOR TESTING - LIMIT TO ONE CLOUD FOR TESTING: cloud type: azure_v2, google, amazon
#  $cloud_href_filter = rs_cm.clouds.get(filter: [ "cloud_type==amazon" ]).href[]

  call err_utilities.log("seeded cloud_costs_hash:", to_s($cloud_costs_hash))

   # Build an array of cpu counts for the pricing API filter
   # If the 1 CPU option was selected, also look at 2 CPUs since pricing can be a bit mushy in that range and a 2 CPU 
   # instance type in some clouds may be chepaer than a 1 CPU option in other clouds.
   $cpu_count_array = [ $cpu_count ]
   if $cpu_count == 1
     $cpu_count_array = $cpu_count_array + [ 2 ]
   end

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
      
   call err_utilities.log(join(["pricing filter: "]), to_s($filter))
           
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
     
   call err_utilities.log(join(["price_hash_array size: ", size($price_hash_array)]), "")
     
   # Now we need to find the best pricing info for the vanilla Linux/Unix platform
   # with the minimum cpu and ram for the given cloud
   $cloud_best_price = 100000
   foreach $price_hash in $price_hash_array do
     
   # Need to figure out which cloud vendor we have here
   if contains?(keys($price_hash["priceable_resource"]), ["public_cloud_vendor_name"])
      $found_cloud_vendor = $price_hash["priceable_resource"]["public_cloud_vendor_name"]
   else
     # get the cloud name and back into the "found_cloud_vendor" value so subsequent logic will work as expected.
     # this is needed since the API may not always return a public_cloud_vendor_name value
     $cloud_href = $price_hash["purchase_option"]["cloud_href"]
     @cloud = rs_cm.get(href: $cloud_href)
     $cloud_name = @cloud.name
     if $cloud_name =~ /Azure/
       $found_cloud_vendor = "Microsoft Azure"
     elsif $cloud_name =~ /Google/
       $found_cloud_vendor = "Google"
     elsif $cloud_name =~ /EC2/
       $found_cloud_vendor = "Amazon Web Services"
     else
       $found_cloud_vendor = "VMware"
     end
   end
         
#     call err_utilities,log(join(["found vendor: ", $found_cloud_vendor]), "")

     
     # We are ok with any Google or Azure type.
     # But we need to avoid looking at AWS EBS-backed instance types since we currently use an MCI that requires ephemeral disk based instance types in AWS.
     # Also the Google price_hash does not have a local_disk_size attribute so we can't just look at that.
     # Hence a multidimensional condition test
#     if logic_or(logic_or(logic_or($found_cloud_vendor == "Google", $found_cloud_vendor == "Microsoft Azure"), $found_cloud_vendor == "VMware"), logic_and($found_cloud_vendor == "Amazon Web Services", to_s($price_hash["priceable_resource"]["local_disk_size"]) != "0.0"))
    ### TODO support VMware
    if logic_or(logic_or($found_cloud_vendor == "Google", $found_cloud_vendor == "Microsoft Azure"), logic_and($found_cloud_vendor == "Amazon Web Services", to_s($price_hash["priceable_resource"]["local_disk_size"]) != "0.0"))

       $purchase_options = keys($price_hash["purchase_option"])
         
       # Check the RAM offering for the given instance type to make sure it meets the minimum required by the user
       # Although there is a memory filter in the pricing API, this is easier than guessing what possible memory configs are available by the differen cloud providers.
       $memory = to_n($price_hash["priceable_resource"]["memory"])
       if $memory >= to_n($ram_count)
         # then it's a contender
         # call err_utilities.log(join(["found a contender price_hash for ", $found_cloud_vendor]), to_s($price_hash))

           # There may be more than one usage_charge elements in the returned array. So find one that is NOT an option since this is the base price we'll be using
           $price = ""
           foreach $usage_charge in $price_hash["usage_charges"] do
              $price = $usage_charge["price"]
#              call err_utilities.log(join(["Found price for ", $found_cloud_vendor, "; price: ", $price]), to_s($price_hash))
           end
           
           # Is it cheapest so far?
           if to_n($price) < $cloud_costs_hash[$found_cloud_vendor]["price"]

             if ($found_cloud_vendor == "Microsoft Azure")
                $instance_type_name = $price_hash["priceable_resource"]["name"]
                $instance_type_name = gsub($instance_type_name, " ", "_")
                if !($instance_type_name =~ /^Basic/)
                  $instance_type_name = "Standard_"+$instance_type_name
                end
                $price_hash["priceable_resource"]["name"] = $instance_type_name
             end
             
             # Even if it's cheaper, make sure it's a supported instance type 
             call checkInstanceType($price_hash["purchase_option"]["cloud_href"], $price_hash["priceable_resource"]["name"], $supported_instance_types_hash) retrieve $supported_instance_types_hash, $usableInstanceType
             if $usableInstanceType # the pricing API returned an instance type that is supported for the account
               $cloud_best_price = to_n($price)
               $cloud_href = $price_hash["purchase_option"]["cloud_href"]

               $instance_type = $price_hash["priceable_resource"]["name"]
               @cloud = rs_cm.clouds.get(href: $cloud_href)
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
                 "datacenter_name" : $cloud_costs_hash[$found_cloud_vendor]["datacenter_name"], # carry the datacenter_name in case there's another hit for this cloud vendor
                 "datacenter_href": $datacenter_href
               }
               $cloud_costs_hash[$found_cloud_vendor] = $cloud_info
             end # usable instance type check
           end # price comparison
       end # RAM check
    end # EBS-backed instance type test
   end # price_hash loop
end


define scale_out(@app_server, @lb_server) return $app_cost do
 call server_array_utilities.scale_out_array(@app_server, @lb_server)
 call calc_app_cost(@app_server) retrieve $app_cost
end

define scale_in(@app_server) return $app_cost do
 call server_array_utilities.scale_in_array(@app_server)
 call calc_app_cost(@app_server) retrieve $app_cost
end


# Calculate the application cost
define calc_app_cost(@web_tier) return $app_cost do
  
  # assume we aren't doing cost data (e.g. if user explicitly selected a cloud the CAT doesn't do costing in that case)
  $app_cost = null
  $instance_cost = null
  
  # Get the hourly cost that we may have stored as a tag
  $tags = rs_cm.tags.by_resource(resource_hrefs: [@@deployment.href])
  $tag_array = $tags[0][0]['tags']
  $cost_tagged = false
  foreach $tag_item in $tag_array do
    if $tag_item['name'] =~ /instancecost/
      $tag = $tag_item['name']
      $instance_cost = to_n(split($tag, "=")[1])
    end
  end
  
  if $instance_cost  # Then we have instance cost information and so can calculate application cost
    # see how many web server instances there are
    @web_servers = select(@web_tier.current_instances(), {"state":"/^(operational|stranded)/"})
    $num_web_servers = size(@web_servers)
    # Ruby floating point arithmetic can cause strange results. Google it.
    # So to deal with it, we turn everything into an integer when doing the multiplications and then bring it back down to dollars and cents at the end.
    # We multiply/divide by 1000 to account for some of the pricing out there that goes to half-cents.
    $calculated_app_cost = (($num_web_servers + 3) * ($instance_cost * 1000))/1000  
    $app_cost = to_s($calculated_app_cost)
  end
  
end

# Checks instance type to see if it is supported by the given, attached cloud
define checkInstanceType($cloud_href, $instance_type, $supported_instance_types_hash) return $supported_instance_types_hash, $usableInstanceType do
  
  # add instance types for the cloud_href if not already in the instance types hash
  if logic_not($supported_instance_types_hash[$cloud_href])

    @cloud=rs_cm.clouds.get(href: $cloud_href)
    @instance_types = @cloud.instance_types().get()
    $instance_type_names=@instance_types.name[]
    $supported_instance_types_hash[$cloud_href] = $instance_type_names
    
    #call err_utilities.log("Gathered instance types for cloud, "+@cloud.name+", cloud_href: "+$cloud_href, to_s($instance_type_names))
  end
  
  # Check if the instance type found in the pricing API is a supported instance type
  $usableInstanceType = contains?($supported_instance_types_hash[$cloud_href], [$instance_type])
  
#  if logic_not($usableInstanceType)
#    call err_utilities.log(join(["Found unsupported instance type, ", to_s($instance_type), " in cloud, ", to_s($cloud_href)]), "")
#  end
end



