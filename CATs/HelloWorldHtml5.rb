DEPRECATED - the AppStack_CpuRamDriven CAT is taking the place of this one in the PFT portfolio.
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
# Deploys a basic two-tiered, scalable website.
# User can pick the type of linux server: CentOS or Ubuntu.
# User can scale out and scale in the backend servers.
# Installs and sets up simple HTML5 website with user-supplied "Hello World" type text.
# It automatically imports the ServerTemplate it needs.
# Also, if needed by the target cloud, the security group and/or ssh key, etc. is automatically created by the CAT.


# Required prolog
name 'D) Hello World Web Site'
rs_ca_ver 20131202
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/html5.png)

Launches a scalable HTML 5 web site with user-provided text."
long_description "Launches a scalable HTML 5 website with user-provided text.\n
Use \"More Actions\" button to modify text after launch.\n
Additionally, you can scale out (i.e. add) additional web servers or scale in (i.e. remove) web servers.\n
\n
Clouds Supported: <B>AWS, Azure, Google</B>"

##################
# User inputs    #
##################
parameter "param_location" do 
  category "User Inputs"
  label "Cloud" 
  type "string" 
  description "Cloud to deploy in." 
  allowed_values "AWS", "Azure", "Google"
  default "AWS"
end

parameter "param_servertype" do
  category "User Inputs"
  label "Linux Server Type"
  type "list"
  description "Type of Linux server to launch"
  allowed_values "CentOS 6.6", 
    "Ubuntu 12.04"
  default "CentOS 6.6"
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
  category "Output"
  description "Click to see your web site."
end

output "lb_status" do
  label "Load Balancer Status Page" 
  category "Output"
  description "Accesses Load Balancer status page"
end

##############
# MAPPINGS   #
##############
mapping "map_cloud" do {
  "AWS" => {
    "cloud" => "EC2 us-east-1",
    "zone" => null, # We don't care which az AWS decides to use.
    "instance_type" => "m3.medium",
    "sg" => '@sec_group',  
    "ssh_key" => "@ssh_key",
    "pg" => null,
  },
  "Azure" => {   
    "cloud" => "Azure East US",
    "zone" => null,
    "instance_type" => "medium",
    "sg" => null, 
    "ssh_key" => null,
    "pg" => "@placement_group",
  },
  "Google" => {
    "cloud" => "Google",
    "zone" => "us-central1-c", # launches in Google require a zone
    "instance_type" => "n1-standard-2",
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
  cloud map( $map_cloud, $param_location, "cloud" )
  datacenter map($map_cloud, $param_location, "zone")
  instance_type map($map_cloud, $param_location, "instance_type")
  server_template_href find(map($map_st, "load_balancer", "name"), revision: map($map_st, "load_balancer", "rev"))
  multi_cloud_image find(map($map_mci, $param_servertype, "mci"), revision: map($map_mci, $param_servertype, "mci_rev"))
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  placement_group_href map($map_cloud, $param_location, "pg")
  security_group_hrefs map($map_cloud, $param_location, "sg")  
  inputs do {
    "lb/session_stickiness" => "text:false",  # As a demo, we want to show the load balancing as much as possible
    "lb_haproxy/algorithm" => "text:roundrobin",
    "rightscale/security_updates" => "text:enable", # Enable security updates
  } end
end


resource "web_tier", type: "server_array" do
  name 'Hello World Web Tier'
  cloud map( $map_cloud, $param_location, "cloud" )
  datacenter map($map_cloud, $param_location, "zone")
  instance_type map($map_cloud, $param_location, "instance_type")
  server_template_href find(map($map_st, "web_server", "name"), revision: map($map_st, "web_server", "rev")) 
  multi_cloud_image find(map($map_mci, $param_servertype, "mci"), revision: map($map_mci, $param_servertype, "mci_rev"))
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  placement_group_href map($map_cloud, $param_location, "pg")
  security_group_hrefs map($map_cloud, $param_location, "sg")  
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
  cloud map( $map_cloud, $param_location, "cloud" )
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
  cloud map($map_cloud, $param_location, "cloud")
end

### Placement Group ###
resource "placement_group", type: "placement_group" do
#  condition $needsPlacementGroup

  name last(split(@@deployment.href,"/"))
  cloud map($map_cloud, $param_location, "cloud")
end 

##################
# Permissions    #
##################
permission "import_servertemplates" do
  actions   "rs.import"
  resources "rs.publications"
end

##################
# CONDITIONS     #
##################

# Used to decide whether or not to pass an SSH key or security group when creating the servers.
condition "needsSshKey" do
  equals?($param_location, "AWS")
end

condition "needsSecurityGroup" do
  logic_or(equals?($param_location, "AWS"), equals?($param_location, "Google"))
end

condition "inAzure" do
  equals?($param_location, "Azure")
end

condition "needsPlacementGroup" do
  equals?($param_location, "Azure")
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
  } end
end

operation "Update Web Site Text" do
  description "Update the text displayed on the web site."
  definition "update_website"
end

operation "Scale Out" do
  description "Adds (scales out) a web server."
  definition "scale_out_array"
end

operation "Scale In" do
  description "Scales in a web server."
  definition "scale_in_array"
end




##########################
# DEFINITIONS (i.e. RCL) #
##########################

# Launch the servers concurrently and return the link information  
define launch_servers(@lb, @web_tier, @ssh_key, @sec_group, @sec_group_rule_http, @placement_group, $map_st, $map_cloud, $param_location, $param_webtext, $needsSshKey, $needsSecurityGroup, $needsPlacementGroup, $inAzure) return @lb, @web_tier, @ssh_key, @sec_group, $server_ip_address, $lb_status_link, $param_webtext do

  # Need the cloud name later on
  $cloud_name = map( $map_cloud, $param_location, "cloud" )

  # Check if the selected cloud is supported in this account.
  # Since different PIB scenarios include different clouds, this check is needed.
  # It raises an error if not which stops execution at that point.
  call checkCloudSupport($cloud_name, $param_location)
  
  # Find and import the server template - just in case it hasn't been imported to the account already
  call importServerTemplate($map_st)
  
  # Configure and store the web text provided by the user.
  call configureWebText($param_webtext, @web_tier) retrieve $param_webtext
  
  # Provision all the needed resources
  
  # Provision the SSH key if applicable.
  if $needsSshKey
    provision(@ssh_key)
  end

  # Provision the security group rules if applicable. (The security group itself is created when the server is provisioned.)
  if $needsSecurityGroup
    provision(@sec_group_rule_http)
  end
  
  # Provision the placement group if applicable
  if $needsPlacementGroup
    provision(@placement_group)
  end
  
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
  if $inAzure
     @bindings = rs.clouds.get(href: @lb.current_instance().cloud().href).ip_address_bindings(filter: ["instance_href==" + @lb.current_instance().href])
     @binding = select(@bindings, {"private_port":80})
     $server_ip_address = join(["http://", to_s(@lb.current_instance().public_ip_addresses[0]), ":", @binding.public_port])
     $lb_status_link = join(["http://", to_s(@lb.current_instance().public_ip_addresses[0]), ":", @binding.public_port, "/haproxy-status"])
  else
     $server_ip_address = join(["http://", to_s(@lb.current_instance().public_ip_addresses[0])])
     $lb_status_link = join(["http://", to_s(@lb.current_instance().public_ip_addresses[0]), "/haproxy-status"])
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
define scale_out_array(@web_tier) do
  task_label("Scale out application server.")
  @task = @web_tier.launch(inputs: {})

  $wake_condition = "/^(operational|stranded|stranded in booting|stopped|terminated|inactive|error)$/"
  sleep_until all?(@web_tier.current_instances().state[], $wake_condition)
  if !all?(@web_tier.current_instances().state[], "operational")
    raise "Some instances failed to start"    
  end
end

# Scale in (remove) server
define scale_in_array(@web_tier) do
  task_label("Scale in web server array.")

  @terminable_servers = select(@web_tier.current_instances(), {"state":"/^(operational|stranded)/"})
  if size(@terminable_servers) > 0 
    @server_to_terminate = first(@terminable_servers)
    @server_to_terminate.terminate()
    sleep_until(@server_to_terminate.state != "operational" )
  else
    rs.audit_entries.create(audit_entry: {auditee_href: @web_tier.href, summary: "Scale In: No terminatable server currently found in the server array"})
  end
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
