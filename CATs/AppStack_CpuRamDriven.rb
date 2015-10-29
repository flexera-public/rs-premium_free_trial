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
# Deploys a two-tiered, scalable website.
# Picks least expensive cloud and instance type based on user-specified CPU and RAM.
# 
# TO-DOs
# Add support for EBS-backed instance types in AWS.
# Improve formatting of the cloud cost info outputs.


# Required prolog
name 'D) App Stack - Least Expensive Cloud'
rs_ca_ver 20131202
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/best_price.png)

Launches a scalable HTML 5 web site with user-provided text in least expensive cloud based on user-specified CPU and RAM."
long_description "Launches a scalable HTML 5 website with user-provided text.\n
Cloud and instance type selected by finding least expensive option that meets the minimum by CPU/RAM requirements specified by user.\n
\n
Use \"More Actions\" button to modify text after launch.\n
Additionally, you can scale out (i.e. add) additional web servers or scale in (i.e. remove) web servers.\n
\n
Clouds Supported: <B>AWS, Azure, Google</B>\n"

##################
# User inputs    #
##################
parameter "param_servertype" do
  category "User Inputs"
  label "Linux Server Type"
  type "list"
  description "Type of Linux server to launch"
  allowed_values "CentOS 6.6", 
    "Ubuntu 12.04"
  default "CentOS 6.6"
end

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

parameter "param_webtext" do 
  category "User Inputs"
  label "Web Site Text" 
  type "string" 
  description "Text to display on the web site." 
  constraint_description "No carriage returns are allowed."
  allowed_pattern '^.+$'
  default "Hello World!"
end

################################
# Outputs returned to the user #
################################

output "site_link" do
  label "Web Site URL"
  category "Application Links"
  description "Click to see your web site."
end

output "lb_status" do
  label "Load Balancer Status Page" 
  category "Application Links"
  description "Accesses Load Balancer status page"
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


##############
# MAPPINGS   #
##############
mapping "map_cloud" do {
  "AWS" => {
    "cloud_provider" => "Amazon Web Services",
    "cloud_type" => "amazon",
    "zone" => null,
    "sg" => '@sec_group',  
    "ssh_key" => "@ssh_key",
    "pg" => null,
  },
  "Azure" => {   
    "cloud_provider" => "Microsoft Azure",
    "cloud_type" => "azure",
    "zone" => null,
    "sg" => null, 
    "ssh_key" => null,
    "pg" => "@placement_group",
  },
  "Google" => {
    "cloud_provider" => "Google",
    "cloud_type" => "google",
    "zone" => "needs-a-zone-specified",
    "sg" => '@sec_group',  
    "ssh_key" => null,
    "pg" => null,
  }
}
end

mapping "map_st" do {
  "load_balancer" => {
    "name" => "Load Balancer with HAProxy (v13.5.11-LTS)",
    "rev" => "25",
  },
  "web_server" => {
    "name" => "Simple HTML5 Website",
    "rev" => "6",
  }
} end

mapping "map_mci" do {
  "CentOS 6.6" => {
    "mci" => "RightImage_CentOS_6.6_x64_v13.5_LTS",
    "mci_rev" => "14"
  },
  "Ubuntu 12.04" => {
    "mci" => "RightImage_Ubuntu_12.04_x64_v13.5_LTS",
    "mci_rev" => "11"
  },
} end



############################
# RESOURCE DEFINITIONS     #
############################

### Server Definition ###

resource "lb", type: "server" do
  name "Load Balancer"
#  cloud map( $map_cloud, $param_location, "cloud" )
#  datacenter map($map_cloud, $param_location, "zone")
#  instance_type map($map_cloud, $param_location, "instance_type")
  server_template_href find(map($map_st, "load_balancer", "name"), revision: map($map_st, "load_balancer", "rev"))
  multi_cloud_image find(map($map_mci, $param_servertype, "mci"), revision: map($map_mci, $param_servertype, "mci_rev"))
#  ssh_key_href map($map_cloud, $param_location, "ssh_key")
#  placement_group_href map($map_cloud, $param_location, "pg")
#  security_group_hrefs map($map_cloud, $param_location, "sg")  
  inputs do {
    "lb/session_stickiness" => "text:false",  # As a demo, we want to show the load balancing as much as possible
    "lb_haproxy/algorithm" => "text:roundrobin",
    "rightscale/security_updates" => "text:enable", # Enable security updates
  } end
end


resource "web_tier", type: "server_array" do
  name 'Hello World Web Tier'
#  cloud map( $map_cloud, $param_location, "cloud" )
#  datacenter map($map_cloud, $param_location, "zone")
#  instance_type map($map_cloud, $param_location, "instance_type")
  server_template_href find(map($map_st, "web_server", "name"), revision: map($map_st, "web_server", "rev")) 
  multi_cloud_image find(map($map_mci, $param_servertype, "mci"), revision: map($map_mci, $param_servertype, "mci_rev"))
#  ssh_key_href map($map_cloud, $param_location, "ssh_key")
#  placement_group_href map($map_cloud, $param_location, "pg")
#  security_group_hrefs map($map_cloud, $param_location, "sg")  
  inputs do {
    # WEBTEXT input is managed at the deployment level so that it is persistent across stop/starts
    # "WEBTEXT" => join(["text:", $param_webtext])
    "SECURITY_UPDATES" => "text:enable" # Enable security updates
  } end
  state "enabled"
  array_type "alert"
  elasticity_params do {
    "bounds" => {
      "min_count"            => 1,
      "max_count"            => 5 # Limited to 5 to avoid POCs deploying too many servers.
    },
    "pacing" => {
      "resize_calm_time"     => 5, 
      "resize_down_by"       => 1,
      "resize_up_by"         => 1
    },
    "alert_specific_params" => {
      "decision_threshold"   => 51,
      "voters_tag_predicate" => "Hello World Web Tier"
    }
  } end
end

### Security Group Definitions ###
# Note: Even though not all environments need or use security groups, the launch operation/definition will decide whether or not
# to provision the security group and rules.

resource "sec_group", type: "security_group" do
#  condition $needsSecurityGroup

  name join(["HelloWorldSecGrp-",@@deployment.href])
  description "Hello World application security group."
#  cloud map( $map_cloud, $param_location, "cloud" )
end

resource "sec_group_rule_http", type: "security_group_rule" do
#  condition $needsSecurityGroup

  name "Hello World HTTP Rule"
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
  description "Launch the servers."
  definition "launch_servers"
  output_mappings do {
    $site_link => $server_ip_address,
    $lb_status => $lb_status_link,
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
    $azure_instance_price_output => $azure_instance_price
  } end
end

operation "Update Web Site Text" do
  description "Update the text displayed on the web site."
  definition "update_website"
end

operation "Scale Out" do
  description "Adds (scales out) a web server."
  definition "scale_out_array"
  output_mappings do {
    $hourly_app_cost => $app_cost
  } end
end

operation "Scale In" do
  description "Scales in a web server."
  definition "scale_in_array"
  output_mappings do {
    $hourly_app_cost => $app_cost
  } end
end




##########################
# DEFINITIONS (i.e. RCL) #
##########################
  

# Launch the servers concurrently and return the link information  
define launch_servers(@lb, @web_tier, @ssh_key, @sec_group, @sec_group_rule_http, @placement_group, $map_st, $map_cloud, $param_cpu, $param_ram, $param_webtext) return @lb, @web_tier, @ssh_key, @sec_group, $server_ip_address, $lb_status_link, $param_webtext, $param_location, $cheapest_cloud, $cheapest_instance_type, $app_cost, $aws_cloud, $aws_instance_type, $aws_instance_price, $google_cloud, $google_instance_type, $google_instance_price, $azure_cloud, $azure_instance_type, $azure_instance_price do

  # Find and import the server template - just in case it hasn't been imported to the account already
  call importServerTemplate($map_st)
    
  # Configure and store the web text provided by the user.
  call configureWebText($param_webtext, @web_tier) retrieve $param_webtext
  
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
  rs.tags.multi_add(resource_hrefs: [@@deployment.href], tags: [join(["hello_world:instancecost=",$cheapest_cost])])

  call audit_log(join(["cheapest cloud: ",$cheapest_cloud]), "")

  foreach $cloud in keys($map_cloud) do
    if $cheapest_cloud == map($map_cloud, $cloud, "cloud_provider")
      $param_location = $cloud
    end
  end
      
  call audit_log(join(["param_location: ",$param_location]), "")

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
  
  $lb_hash = to_object(@lb)
  $lb_hash["fields"]["cloud_href"] = $cheapest_cloud_href
  $lb_hash["fields"]["instance_type_href"] = $cheapest_instance_type_href
    
  $webtier_hash = to_object(@web_tier)
  $webtier_hash["fields"]["cloud_href"] = $cheapest_cloud_href
  $webtier_hash["fields"]["instance_type_href"] = $cheapest_instance_type_href

  
  if map($map_cloud, $param_location, "zone")   
    $lb_hash["fields"]["datacenter_href"] = $cheapest_datacenter_href
    $webtier_hash["fields"]["datacenter_href"] = $cheapest_datacenter_href
  end
  
  if map($map_cloud, $param_location, "ssh_key")
    provision(@ssh_key)
    $lb_hash["fields"]["ssh_key_href"] = @ssh_key.href
    $webtier_hash["fields"]["ssh_key_href"] = @ssh_key.href
  end
  
  if map($map_cloud, $param_location, "pg")
    provision(@placement_group)
    $lb_hash["fields"]["placement_group_href"] = @placement_group.href
    $webtier_hash["fields"]["placement_group_href"] = @placement_group.href
  end
  
  if map($map_cloud, $param_location, "sg")
    provision(@sec_group_rule_http)
    $lb_hash["fields"]["security_group_hrefs"] = [@sec_group.href]
    $webtier_hash["fields"]["security_group_hrefs"] = [@sec_group.href]
  end
  @lb = $lb_hash  
  @web_tier = $webtier_hash

  # Provision the servers (concurrently)
  concurrent return @lb, @web_tier do
    sub task_name:"Launch LB" do
      task_label("Launching LB")
      $lb_retries = 0 
      sub on_error: handle_retries($lb_retries) do
        $lb_retries = $lb_retries + 1
        provision(@lb) 
      end
    end
  
    sub task_name:"Launch Web Tier" do
      task_label("Launching Web Tier")
      $webtier_retries = 0 
      sub on_error: handle_retries($webtier_retries) do
        $webtier_retries = $webtier_retries + 1
        provision(@web_tier)
      end
    end
  end
  
  # Remind the Load Balancer to attach to the application instances which may have come up before it did during the concurrent call above.
  call run_recipe_inputs(@lb, "lb::do_attach_all", {}) 
  
  # If deployed in Azure one needs to provide the port mapping that Azure uses.
  if $param_location == "Azure"
     @bindings = rs.clouds.get(href: @lb.current_instance().cloud().href).ip_address_bindings(filter: ["instance_href==" + @lb.current_instance().href])
     @binding = select(@bindings, {"private_port":80})
     $server_ip_address = join(["http://", to_s(@lb.current_instance().public_ip_addresses[0]), ":", @binding.public_port])
     $lb_status_link = join(["http://", to_s(@lb.current_instance().public_ip_addresses[0]), ":", @binding.public_port, "/haproxy-status"])
  else
     $server_ip_address = join(["http://", to_s(@lb.current_instance().public_ip_addresses[0])])
     $lb_status_link = join(["http://", to_s(@lb.current_instance().public_ip_addresses[0]), "/haproxy-status"])
  end
  
  call calc_app_cost(@web_tier) retrieve $app_cost
 
end 

# Calculate the cost of using the different clouds found in the $map_cloud mapping
define find_cloud_costs($map_cloud, $cpu_count, $ram_count) return $cloud_costs_hash do
  
    $cloud_costs_hash = {}
    # Seed the cloud info
    $cloud_info = {
      "price": 10000,
      "cloud_name": "",
      "cloud_href": "",
      "instance_type": "",
      "instance_type_href": "",
      "datacenter_href": ""
    }
    $cloud_href_filter = []
    $cloud_provider_filter = []
    foreach $cloud in keys($map_cloud) do
      
      $public_cloud_vendor_name = map($map_cloud, $cloud, "cloud_provider")
  
      # Seed the cloud hash and build a list of the providers for the pricing filter below
      $cloud_costs_hash[$public_cloud_vendor_name] = $cloud_info
      $cloud_provider_filter << $public_cloud_vendor_name
      
      # Build up a list of cloud hrefs for the pricing filter below
      $cloud_href_array = rs.clouds.get(filter: join(["cloud_type==",map($map_cloud, $cloud, "cloud_type")])).href[]
      $cloud_href_filter = $cloud_href_filter + $cloud_href_array
    end
  
#  call audit_log("seeded cloud_costs_hash:", to_s($cloud_costs_hash))

   # Build an array of cpu counts for the pricing API filter
   $cpu_count_array = []
   $numcpu = to_n($param_cpu)
   $maxcpu = $numcpu *2
   while $numcpu <= $maxcpu do
     $cpu_count_array << $numcpu
     $numcpu = $numcpu + 1
   end
   
   # pricing filters
   $filter = {
     public_cloud_vendor_name: $cloud_provider_filter,
     cloud_href: $cloud_href_filter,
     cpu_count: $cpu_count_array,
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
     
     $found_public_cloud_vendor = $price_hash["priceable_resource"]["public_cloud_vendor_name"]
     
     # We are ok with any Google or Azure type.
     # But we need to avoid looking at AWS EBS-backed instance types since we currently use an MCI that requires ephemeral disk based instance types in AWS.
     # Also the Google price_hash does not have a local_disk_size attribute so we can't just look at that.
     # Hence a multidimensional condition test
     if logic_or(logic_or($found_public_cloud_vendor == "Google", $found_public_cloud_vendor == "Microsoft Azure"), logic_and($found_public_cloud_vendor == "Amazon Web Services", $price_hash["priceable_resource"]["local_disk_size"] != "0.0"))
#           call audit_log(join(["price_hash for ", $found_public_cloud_vendor]), to_s($price_hash))

       $purchase_options = keys($price_hash["purchase_option"])
         
       # Check the RAM offering for the given instance type to make sure it meets the minimum required by the user
       # Although there is a memory filter in the pricing API, this is easier than guessing what possible memory configs are available by the differen cloud providers.
       $memory = to_n($price_hash["priceable_resource"]["memory"])
       if $memory >= to_n($ram_count)
         # then it's a contender
       
         # There may be more than one usage_charge elements in the returned array. So find one that is NOT an option since this is the base price we'll be using
         $price = ""
         foreach $usage_charge in $price_hash["usage_charges"] do
           if $usage_charge["option"] == false
              $price = $usage_charge["price"]

#                  call audit_log(join(["Found price for ", $found_public_cloud_vendor, "; price: ", $price]), to_s($price_hash))
           end
         end
         
         # Did we find a cheaper price?
         if to_n($price) < $cloud_costs_hash[$found_public_cloud_vendor]["price"]
           $cloud_best_price = to_n($price)
           $cloud_href = $price_hash["purchase_option"]["cloud_href"]
           $instance_type = $price_hash["priceable_resource"]["name"]
           @cloud = rs.clouds.get(href: $cloud_href)
           $instance_type_href = @cloud.instance_types(filter: [join(["name==",$instance_type])]).href
           $datacenter_href = ""
           if contains?($purchase_options, ["datacenter_name"])
              $datacenter_name = $price_hash["purchase_option"]["datacenter_name"]
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
           $cloud_costs_hash[$found_public_cloud_vendor] = $cloud_info
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
    if $tag_item['name'] =~ /hello_world:instancecost/
      $tag = $tag_item['name']
      $instance_cost = to_n(split($tag, "=")[1])
    end
  end
  
  if $instance_cost  # Then we have instance cost informatin and so can calculate application cost
    # see how many web server instances there are
    @web_servers = select(@web_tier.current_instances(), {"state":"/^(operational|stranded)/"})
    $num_web_servers = size(@web_servers)
    $calculated_app_cost = ($num_web_servers + 1) * $instance_cost  # add one to the number of web servers to account for the load balancer
    $app_cost = to_s($calculated_app_cost)
  end
  
end

# Store the web text in a tag attached to the deployment.
# This allows the web text to persist across stop/starts even though in this CAT, the stop actually terminates the server.
define configureWebText($webtext, @web_tier) return $webtext do
  
  $tags = rs.tags.by_resource(resource_hrefs: [@@deployment.href])
  $tag_array = $tags[0][0]['tags']
  $already_tagged = false
  foreach $tag_item in $tag_array do
    if $tag_item['name'] =~ /hello_world:webtext/
      $already_tagged = true
    end
  end
  
  # Store the web text if this is the first time launching. 
  if logic_not($already_tagged)
    call storeWebText($webtext)
  else
    # Get the web text because this is a start after stop and since we're using ephemeral disks, we need to 
    # use the stored webtext to maintain continuity since last time.
    call getStoredWebText() retrieve $webtext 
  end
  
  # Now set the webtext as a deployment level input so the underlying servers will use it.
  call setWebText($webtext, @web_tier)
end
  

# Sets the webtext as an input on the Deployment and on any existing instances.
define setWebText($webtext, @web_tier) do  
  # Set the deployment level input
  $inp = {
   "WEBTEXT": join(["text:", $webtext])
   }
  @@deployment.multi_update_inputs(inputs: $inp)
  
  # if @web_tier is simply a declaration at this time, then 
  # it doesn't exist as a resource that can be acted upon. So don't.
  if logic_not(equals?(type(@web_tier), "declaration"))
    @web_tier.current_instances().multi_update_inputs(inputs: $inp)
  end
end

# Stores the webtext as a tag for future reference.
define storeWebText($webtext) do
  rs.tags.multi_add(resource_hrefs: [@@deployment.href], tags: [join(["hello_world:webtext=",$webtext])])
end # storeWebText

# Retrieve the webtext from the deployment tag
define getStoredWebText() return $webtext do
  
  # Initialize things
  $webtext = "WEB TEXT NOT FOUND"
  
  # Get the current set of tags
  $tags = rs.tags.by_resource(resource_hrefs: [@@deployment.href])
  $tag_array = $tags[0][0]['tags']
  foreach $tag_item in $tag_array do
    $tag = $tag_item['name']
    if $tag =~ /hello_world:webtext/
      $webtext = split($tag, "=")[1]
    end
  end  
end # getStoredWebText

#
# Modify the web page text
#
define update_website(@web_tier, $param_webtext) do
  task_label("Update Web Page")
  
  $webtext = $param_webtext
  
  # Store the webtext for future starts.
  call storeWebText($webtext)
  
  # Set the webtext for the existing deployment and instances.
  call setWebText($webtext, @web_tier)
    
  # Now run the script to update the web page text on each of the underlying running web servers.
  $script_name = "Hello World - HTML5"
  @script = rs.right_scripts.get(filter: join(["name==",$script_name]))
  $right_script_href=@script.href

  @running_servers = select(@web_tier.current_instances(), {"state":"operational"})
  @tasks = @running_servers.run_executable(right_script_href: $right_script_href, inputs: {})
  sleep_until(all?(@tasks.summary[], "/^(completed|failed)/"))

  if any?(@tasks.summary[], "/^failed/")
    raise "Failed to run " + $right_script_href + " on one or more instances"
  end
end

# Scale out (add) server
define scale_out_array(@web_tier) return $app_cost do
  task_label("Scale out application server.")
  @task = @web_tier.launch(inputs: {})

  $wake_condition = "/^(operational|stranded|stranded in booting|stopped|terminated|inactive|error)$/"
  sleep_until all?(@web_tier.current_instances().state[], $wake_condition)
  if !all?(@web_tier.current_instances().state[], "operational")
    raise "Some instances failed to start"    
  end
  
  call calc_app_cost(@web_tier) retrieve $app_cost

end

# Scale in (remove) server
define scale_in_array(@web_tier)  return $app_cost do
  task_label("Scale in web server array.")

  @terminable_servers = select(@web_tier.current_instances(), {"state":"/^(operational|stranded)/"})
  if size(@terminable_servers) > 0 
    @server_to_terminate = first(@terminable_servers)
    @server_to_terminate.terminate()
    sleep_until(@server_to_terminate.state != "operational" )
  else
    rs.audit_entries.create(audit_entry: {auditee_href: @web_tier.href, summary: "Scale In: No terminatable server currently found in the server array"})
  end
  
  call calc_app_cost(@web_tier) retrieve $app_cost

end

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

# Helper functions
define handle_retries($attempts) do
  if $attempts < 3
    $_error_behavior = "retry"
    sleep(60)
  end
end

define run_recipe_inputs(@target, $recipe_name, $recipe_inputs) do
  @task = @target.current_instance().run_executable(recipe_name: $recipe_name, inputs: $recipe_inputs)
  sleep_until(@task.summary =~ "^(completed|failed)")
  if @task.summary =~ "failed"
    raise "Failed to run " + $recipe_name
  end
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
