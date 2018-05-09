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
# Deploys system in least expensive environment based on user-specified CPU and RAM requirements.
# 
# FEATURES
# User specifies minimum CPU and RAM requirements and CAT finds the least expensive cloud in which to launch the app.
# User can use a post-launch action to install a different version of the application software from a Git repo.
# User can scale out or scale in application servers.


name 'D) App Stack - Least Expensive Cloud'
rs_ca_ver 20161221
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/best_price_new.png)

Launches servers in least expensive PUBLIC or PRIVATE cloud based on user-specified CPU and RAM."
long_description "Launches servers in the least expensive environment based on user-specified CPU and RAM requirements.\n
Clouds Supported: <B>AWS, Azure, Google, VMware</B>\n
Pro Tip: Select CPU=1 and RAM=1 to end up in the VMware environment."

import "pft/parameters"
import "pft/mappings"
import "pft/conditions"
import "pft/resources"
import "pft/linux_server_declarations"
import "pft/server_templates_utilities"
import "pft/server_array_utilities"
import "pft/permissions"
import "pft/err_utilities"
import "pft/creds_utilities"
import "pft/mci"
import "pft/mci/linux_mappings", as: "linux_mappings"
 
 
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
  allowed_values 1, 2, 4, 8
  default 2
end

parameter "param_ram" do 
  category "User Inputs"
  label "Minimum Amount of RAM" 
  type "number"
  description "Minimum amount of RAM in GBs needed for the application." 
  min_value 1 
  default 2
end

parameter "param_numservers" do
  like $parameters.param_numservers
end

parameter "param_costcenter" do
  like $parameters.param_costcenter
end


################################
# Outputs returned to the user #
################################
output_set "output_server_ips" do
  label @linux_servers.name
  category "IP Addresses"
end

#output_set "output_server_ips_public" do
#  label "Server Public IP"
#  category "Server Info"
#  description "Public IP address(es) for the server(s)."
#  default_value @linux_server.public_ip_address
#end
#
#output_set "output_server_ips_private" do
#  label "Server Private IP"
#  category "Server Info"
#  description "Private IP address(es) for the server(s)."
#  default_value @linux_server.private_ip_address
#end

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
    "tag_prefix" => "ec2"
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
    "tag_prefix" => "azure"
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
    "tag_prefix" => "google"
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
    "tag_prefix" => "vmware"
  }
}
end

mapping "map_config" do 
  like $linux_server_declarations.map_config
end

mapping "map_image_name_root" do 
 like $linux_mappings.map_image_name_root
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
resource "linux_servers", type: "server", copies: $param_numservers do
  like @linux_server_declarations.linux_server
  # The following attributes are configured in RCL below once we know which cloud we are using.
  # So we overwrite some placeholder values for now.
  cloud map($map_nulls, "place_holder", "null_value")
  datacenter map($map_nulls, "place_holder", "null_value")
  instance_type map($map_nulls, "place_holder", "null_value")
  ssh_key_href map($map_nulls, "place_holder", "null_value")
  placement_group_href map($map_nulls, "place_holder", "null_value")
  security_group_hrefs map($map_nulls, "place_holder", "null_value")
  network_href map($map_nulls, "place_holder", "null_value")
  subnet_hrefs [map($map_nulls, "place_holder", "null_value")]
end

## TO-DO: Set up separate security groups for each tier with rules that allow the applicable port(s) only from the IP of the given tier server(s)
resource "sec_group", type: "security_group" do
  like @resources.sec_group
  cloud map($map_nulls, "place_holder", "null_value") # placeholder until we know which cloud
end

resource "sec_group_rule_ssh", type: "security_group_rule" do
  like @resources.sec_group_rule_ssh
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

operation "enable" do
  description "Get information once the app has been launched"
  definition "enable"
  resource_mappings do {
    @linux_servers => @servers
  } end
  output_mappings do {
    $output_server_ips => $server_ips
  } end
end

##########################
# DEFINITIONS (i.e. RCL) #
##########################
define launch_servers(@linux_servers, @ssh_key, @sec_group, @sec_group_rule_ssh, @placement_group, $map_cloud, $map_config, $map_image_name_root, $param_cpu, $param_ram, $param_numservers, $param_costcenter)  return @linux_servers, @sec_group, @ssh_key, @placement_group, $param_location, $cheapest_cloud, $cheapest_instance_type, $app_cost, $aws_cloud, $aws_instance_type, $aws_instance_price, $google_cloud, $google_instance_type, $google_instance_price, $azure_cloud, $azure_instance_type, $azure_instance_price, $vmware_cloud, $vmware_instance_type, $vmware_instance_price do 

  # Calculate where to launch the system
  
  # Use the pricing API to get some numbers
  call find_cloud_costs($map_cloud, $map_config, $param_cpu, $param_ram) retrieve $cloud_costs_hash
  
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
  $cheapest_instance_type = ""
  $cheapest_datacenter_name = ""
  foreach $cloud in keys($cloud_costs_hash) do
    if to_n($cloud_costs_hash[$cloud]["price"]) < $cheapest_cost
      $cheapest_cloud = $cloud
      $cheapest_cloud_href = $cloud_costs_hash[$cloud]["cloud_href"]
      $cheapest_datacenter_name = $cloud_costs_hash[$cloud]["datacenter_name"]
      $cheapest_cost = to_n($cloud_costs_hash[$cloud]["price"])
      $cheapest_instance_type = $cloud_costs_hash[$cloud]["instance_type"]
    end
  end
  @cloud = rs_cm.clouds.get(href: $cheapest_cloud_href)
  
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
    
  # Make sure the MCI is pointing to the latest image for the cloud.
  call mci.updateImage(@cloud.name, $param_location, map($map_config, "mci", "name"), $map_image_name_root)
    
  # Finish configuring the resource declarations so they are ready for launch
      
  # modify resources with the cheapest cloud
  $update_hash = { "cloud_href": $cheapest_cloud_href }
  call modify_resource_definition(@ssh_key, $update_hash) retrieve @ssh_key
  call modify_resource_definition(@sec_group, $update_hash) retrieve @sec_group
  call modify_resource_definition(@placement_group, $update_hash) retrieve @placement_group
  
  $update_hash = { "instance_type_href":$cheapest_instance_type_href} + $update_hash 
  $cheapest_instance_type_href = @cloud.instance_types(filter: [join(["name==",$cheapest_instance_type])]).href
  call modify_resource_definition(@linux_servers, $update_hash) retrieve @linux_servers
   
  if map($map_cloud, $param_location, "zone")  
    $cheapest_datacenter_href = @cloud.datacenters(filter: [join(["name==",$cheapest_datacenter_name])]).href
    $update_hash = { "datacenter_href":$cheapest_datacenter_href }
    call modify_resource_definition(@linux_servers, $update_hash) retrieve @linux_servers
  end
  
  $network_href = ""
  if map($map_cloud, $param_location, "network")  
    @network = find("networks", { name: map($map_cloud, $param_location, "network"), cloud_href: $cheapest_cloud_href })
    $network_href = @network.href
     
    $update_hash = { "network_href":$network_href }
    call modify_resource_definition(@linux_servers, $update_hash) retrieve @linux_servers
  end
  
  if map($map_cloud, $param_location, "subnet")       
    @subnet = find("subnets", { name:map($map_cloud, $param_location, "subnet"),  network_href: $network_href })
    $subnet_href = @subnet.href[]

    $update_hash = { "subnet_hrefs":$subnet_href }
    call modify_resource_definition(@linux_servers, $update_hash) retrieve @linux_servers
  end
  
  if map($map_cloud, $param_location, "ssh_key")
    provision(@ssh_key)
    
    $update_hash = { "ssh_key_href":@ssh_key.href }
    call modify_resource_definition(@linux_servers, $update_hash) retrieve @linux_servers
  end
  
  if map($map_cloud, $param_location, "pg") 
    provision(@placement_group)
    
    $update_hash = { "placement_group_href":@placement_group.href }
    call modify_resource_definition(@linux_servers, $update_hash) retrieve @linux_servers
  end
  
  if map($map_cloud, $param_location, "sg")
    provision(@sec_group_rule_ssh)
    
    $update_hash = { "security_group_hrefs":[@sec_group.href] }
    call modify_resource_definition(@linux_servers, $update_hash) retrieve @linux_servers
  end
  
#  call err_utilities.log("chef_sever object hash", to_s(to_object(@chef_server)))
    
  # At this point we have the server declaration updated with the necessary values from the least expensive cloud search.
  # We've also already provisioned the security groups and ssh keys, etc if needed.
  # So now we are ready to provision the servers. 
  provision(@linux_servers)
  
  call calc_app_cost($param_numservers) retrieve $app_cost
  
  # Tag the servers with the selected project cost center ID.
  $tags=[join([map($map_cloud, $param_location, "tag_prefix"),":costcenter=",$param_costcenter])]
  $instance_hrefs = @@deployment.servers().current_instance().href[]
  # One would normally just pass the entire instance_hrefs[] array to multi_add and so it all in one command.
  # However, the call to the Azure API will at times take too long and time out.
  # So tagging one resource at a time avoids this problem and doesn't add any discernible time to the processing.
  foreach $instance_href in $instance_hrefs do
    rs_cm.tags.multi_add(resource_hrefs: [$instance_href], tags: $tags)
  end 
end 

define enable(@linux_servers) return @servers, $server_ips do
  
   $cloud_type = @linux_servers.current_instance().cloud().cloud_type
    $invSphere =  equals?($cloud_type, "vscale")
    
    # Wait until all the servers have IP addresses
    $server_ips = null
    if $invSphere
      $server_ips = map @server in @linux_servers return $ip do
        sleep_until(@server.private_ip_addresses[0])
        $ip = @server.private_ip_addresses[0]
      end
    else
      $server_ips = map @server in @linux_servers return $ip do
        sleep_until(@server.public_ip_addresses[0])
        $ip = @server.public_ip_addresses[0]
      end
    end
    
    @servers = @linux_servers
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
define find_cloud_costs($map_cloud, $map_config, $cpu_count, $ram_count) return $cloud_costs_hash do
      
  $supported_instance_types_hash = {}

  # Build up a list of cloud hrefs for the pricing filter below
  # We'll only look at clouds that the MCI supports and are of a type in the map_cloud
  $cloud_keys = keys($map_cloud)
  $acceptable_cloud_types = []
  foreach $cloud_key in $cloud_keys do
    $acceptable_cloud_types << map($map_cloud, $cloud_key, "cloud_type")
  end
  
  call err_utilities.log("Building cloud list.", "") # t=0.0001

  $mci_name = map($map_config, "mci", "name")
  $mci_rev = map($map_config, "mci", "rev")
  @mci = find("multi_cloud_images", $mci_name, $mci_rev)
  @mci_settings = @mci.settings()
  $cloud_href_filter = []  # t=0.4
  foreach @setting in @mci_settings do
    sub on_error: skip do  # There may be cloud() links in the collection that are undefined in the account.
      $cloud_type = @setting.cloud().cloud_type
      if contains?($acceptable_cloud_types, [$cloud_type])
        $cloud_href_filter << @setting.cloud().href 
      end
    end
  end  
  
#   
#  ### FOR TESTING - LIMIT TO ONE CLOUD FOR TESTING: cloud type: azure_v2, google, amazon
##  $cloud_href_filter = rs_cm.clouds.get(filter: [ "cloud_type==amazon" ]).href[]
##  $cloud_href_filter = ["/api/clouds/1","/api/clouds/2","/api/clouds/3","/api/clouds/4","/api/clouds/5","/api/clouds/6","/api/clouds/7","/api/clouds/8","/api/clouds/9","/api/clouds/3518","/api/clouds/3519","/api/clouds/3520","/api/clouds/3521","/api/clouds/3522","/api/clouds/3523","/api/clouds/3524","/api/clouds/3525","/api/clouds/3526","/api/clouds/3527","/api/clouds/3528","/api/clouds/3529","/api/clouds/3530","/api/clouds/3531","/api/clouds/3532","/api/clouds/2175","/api/clouds/3482"]
## (VMware vs Azure):  $cloud_href_filter = ["/api/clouds/3470", "/api/clouds/3531"]
#
  call err_utilities.log(join(["cloud_href_filter: "]), to_s($cloud_href_filter))  # t=3-6
  
   # Build an array of cpu counts for the pricing API filter
   # If the 1 CPU option was selected, also look at 2 CPUs since pricing can be a bit mushy in that range and a 2 CPU 
   # instance type in some clouds may be chepaer than a 1 CPU option in other clouds.
   $cpu_count_array = [ $cpu_count ]
   if $cpu_count == 1
     $cpu_count_array = $cpu_count_array + [ 2 ]
   end

   # pricing filters
   $filter = {
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
       filter: to_json($filter), # For Praxis-based APIs (e.g. the pricing API) one needs to to_json() the query string values to avoid URL encoding of the null value in the filter.
       limit: 20000  # max allowed - we want to make sure we get all the prices we can
       }
     )
   
   $price_hash_array = $response["body"]
     
   call err_utilities.log(join(["price_hash_array size: ", size($price_hash_array)]), "") # t=5
     
  # Build a blank cloud costs hash that will filled up as we go through the options.
  $cloud_costs_hash = {}
  $cloud_info = {
    "price": 10000,
    "cloud_name": "",
    "cloud_href": "",
    "instance_type": "",
    "instance_type_href": "",
    "datacenter_name": "",
    "datacenter_href": ""
  }
  foreach $cloud in keys($map_cloud) do
    $cloud_vendor_name = map($map_cloud, $cloud, "cloud_provider")
    # Seed the cloud hash 
    $cloud_costs_hash[$cloud_vendor_name] = $cloud_info
    # add in the datacenter_name if it's in the cloud mapping
    $cloud_costs_hash[$cloud_vendor_name]["datacenter_name"] = map($map_cloud, $cloud, "zone")
  end
  
  call err_utilities.log("seeded cloud_costs_hash:", to_s($cloud_costs_hash))
    
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
    if logic_or(logic_or(logic_or($found_cloud_vendor == "Google", $found_cloud_vendor == "Microsoft Azure"), $found_cloud_vendor == "VMware"), logic_and($found_cloud_vendor == "Amazon Web Services", to_s($price_hash["priceable_resource"]["local_disk_size"]) != "0.0"))
      
       $purchase_options = keys($price_hash["purchase_option"])
         
       # Check the RAM offering for the given instance type to make sure it meets the minimum required by the user
       # Although there is a memory filter in the pricing API, this is easier than guessing what possible memory configs are available by the differen cloud providers.
       $memory = to_n($price_hash["priceable_resource"]["memory"])
       if $memory >= to_n($ram_count)
         # then it's a contender
#          call err_utilities.log(join(["found a contender price_hash for ", $found_cloud_vendor]), to_s($price_hash))

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
               $datacenter_name = ""
               $instance_type = $price_hash["priceable_resource"]["name"]
               if contains?($purchase_options, ["datacenter_name"])  # then set the datacenter with that provided in the pricing info
                  $datacenter_name = $price_hash["purchase_option"]["datacenter_name"]
               elsif $cloud_costs_hash[$found_cloud_vendor]["datacenter_name"]  # then use the datacenter we set in the cloud map - only really needed for VMware env
                  $datacenter_name = $cloud_costs_hash[$found_cloud_vendor]["datacenter_name"]
               end
               $cloud_info = {
                 "price": $cloud_best_price,
                 "cloud_href": $cloud_href,
                 "instance_type": $instance_type,
                 "datacenter_name" : $datacenter_name #$cloud_costs_hash[$found_cloud_vendor]["datacenter_name"] # carry the datacenter_name in case there's another hit for this cloud vendor
               }
               $cloud_costs_hash[$found_cloud_vendor] = $cloud_info
               
             end # usable instance type check
           end # price comparison
       end # RAM check
    end # EBS-backed instance type test
   end # price_hash loop
end # t=10

# Calculate the application cost
define calc_app_cost($num_servers) return $app_cost do
  
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

    # Ruby floating point arithmetic can cause strange results. Google it.
    # So to deal with it, we turn everything into an integer when doing the multiplications and then bring it back down to dollars and cents at the end.
    # We multiply/divide by 1000 to account for some of the pricing out there that goes to half-cents.
    $calculated_app_cost = ($num_servers * ($instance_cost * 1000))/1000  
    $app_cost = to_s($calculated_app_cost)
  end
  
end

# Checks instance type to see if it is supported by the given, attached cloud
define checkInstanceType($cloud_href, $instance_type, $supported_instance_types_hash) return $supported_instance_types_hash, $usableInstanceType do
  
  # add instance types for the cloud_href if not already in the instance types hash
  if logic_not($supported_instance_types_hash[$instance_type])

#    @cloud=rs_cm.clouds.get(href: $cloud_href)
#    @instance_types = @cloud.instance_types().get()
#    $instance_type_names=@instance_types.name[]
#    $supported_instance_types_hash[$cloud_href] = $instance_type_names
    @cloud=rs_cm.clouds.get(href: $cloud_href)
    $instance_type_names = @cloud.instance_types().get().name[]
    foreach $instance_type_name in $instance_type_names do
      $supported_instance_types_hash[$instance_type_name] = true
    end
    
    #call err_utilities.log("Gathered instance types for cloud, "+@cloud.name+", cloud_href: "+$cloud_href, to_s($instance_type_names))
  end
  
  # Check if the instance type found in the pricing API is a supported instance type
#  $usableInstanceType = contains?($supported_instance_types_hash[$cloud_href], [$instance_type])
  $usableInstanceType = $supported_instance_types_hash[$instance_type]

#  if logic_not($usableInstanceType)
#    call err_utilities.log(join(["Found unsupported instance type, ", to_s($instance_type), " in cloud, ", to_s($cloud_href)]), "")
#  end
end



