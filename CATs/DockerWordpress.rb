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
# Deploys a Docker server and automatically installs WordPress.
# It automatically imports the ServerTemplate it needs.
# Also, if needed by the target cloud, the security group and/or ssh key is automatically created by the CAT.
#
# TO-DOs:
#   The ServerTemplate being used supports a docker-compose input. The default is a docker-compose for WordPress.
#   But, the CAT could allow the user to provide a path to additional docker-compoose files that could then be launched/added to the server.
# 
# PREREQUISITES
#   For vSphere Support: 
#     A vSphere environment needs to have been set up and registered with the RightScale account being used for the POC.
#     The environment must be registered as "POC vSphere" to match the cloud mapping used in the code below.
#     The RCA-V must have at least a zone called "POC-vSphere-Zone-1"
#     The image for the MCI in the mapping below needs to be uploaded to the environment.

# Required prolog
name 'C) Docker Container with  WordPress'
rs_ca_ver 20131202
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/docker.png) 

Launch a Docker container with WordPress"
long_description "Launch a Docker server and run WordPress and Database containers.\n
\n
Clouds Supported: <B>AWS, Azure, Google, VMware</B>"

##################
# User inputs    #
##################
parameter "param_location" do 
  category "Deployment Options"
  label "Cloud" 
  type "string" 
  allowed_values "AWS", "Azure", "Google", "VMware" 
  default "Google"
end

parameter "param_costcenter" do 
  category "Deployment Options"
  label "Cost Center" 
  type "string" 
  allowed_values "Development", "QA", "Production"
  default "Development"
end


################################
# Outputs returned to the user #
################################
output "wordpress_url" do
  label "WordPress Link"
  category "Output"
end

output "vmware_note" do
  condition $invSphere
  label "Deployment Note"
  category "Output"
  default_value "Your CloudApp was deployed in a VMware environment on a private network and so is not directly accessible. If you need access to the CloudApp, please contact your RightScale rep for network access."
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
    "mci_mapping" => "Public",
  },
  "Azure" => {   
    "cloud" => "Azure East US",
    "zone" => null,
    "instance_type" => "medium",
    "sg" => null, 
    "ssh_key" => null,
    "pg" => "@placement_group",
    "mci_mapping" => "Public",
  },
  "Google" => {
    "cloud" => "Google",
    "zone" => "us-central1-c", # launches in Google require a zone
    "instance_type" => "n1-standard-2",
    "sg" => '@sec_group',  
    "ssh_key" => null,
    "pg" => null,
    "mci_mapping" => "Public",
  },
  "VMware" => {
    "cloud" => "VMware Private Cloud",
    "zone" => "VMware_Zone_1", # launches in vSphere require a zone being specified  
    "instance_type" => "large",
    "sg" => null, 
    "ssh_key" => "@ssh_key",
    "pg" => null,
    "mci_mapping" => "VMware",
  }
}
end

mapping "map_st" do {
  "docker_server" => {
    "name" => "Docker Technology Demo",
    "rev" => "2",
  }
} end

mapping "map_mci" do {
  "VMware" => { # vSphere 
    "mci_name" => "RightImage_Ubuntu_14.04_x64_v14.2_VMware",   
    "mci_rev" => "7",
  },
  "Public" => { # all other clouds
    "mci_name" => "RightImage_Ubuntu_14.04_x64_v14.2",
    "mci_rev" => "11",
  }
} end

############################
# RESOURCE DEFINITIONS     #
############################

### Server Definition ###
resource "docker_server", type: "server" do
  name 'Docker Server'
  cloud map($map_cloud, $param_location, "cloud")
  datacenter map($map_cloud, $param_location, "zone")
  instance_type map($map_cloud, $param_location, "instance_type")
  server_template_href find(map($map_st, "docker_server", "name"), revision: map($map_st, "docker_server", "rev"))
  multi_cloud_image_href find(map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_name"), revision: map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_rev"))
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  placement_group_href map($map_cloud, $param_location, "pg")
  security_group_hrefs map($map_cloud, $param_location, "sg")  
end

### Security Group Definitions ###
# Note: Even though not all environments need or use security groups, the launch operation/definition will decide whether or not
# to provision the security group and rules.
resource "sec_group", type: "security_group" do
  condition $needsSecurityGroup

  name join(["DockerServerSecGrp-",@@deployment.href])
  description "Docker Server deployment security group."
  cloud map( $map_cloud, $param_location, "cloud" )
end

resource "sec_group_rule_http", type: "security_group_rule" do
  condition $needsSecurityGroup

  name "Docker deployment HTTP Rule"
  description "Allow HTTP access."
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

resource "sec_group_rule_ssh", type: "security_group_rule" do
  condition $needsSecurityGroup
  like @sec_group_rule_http

  name "Docker deployment SSH Rule"
  description "Allow SSH access."
  protocol_details do {
    "start_port" => "22",
    "end_port" => "22"
  } end
end 


### SSH Key ###
resource "ssh_key", type: "ssh_key" do
  condition $needsSshKey

  name join(["sshkey_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
end

### Placement Group ###
resource "placement_group", type: "placement_group" do
  condition $needsPlacementGroup

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
  logic_or(equals?($param_location, "AWS"), equals?($param_location, "VMware"))
end

condition "needsSecurityGroup" do
  logic_or(equals?($param_location, "AWS"), equals?($param_location, "Google"))
end

condition "needsPlacementGroup" do
  equals?($param_location, "Azure")
end

condition "invSphere" do
  equals?($param_location, "VMware")
end

condition "inAzure" do
  equals?($param_location, "Azure")
end

####################
# OPERATIONS       #
####################
operation "launch" do 
  description "Launch the server"
  definition "pre_auto_launch"
end

operation "enable" do
  description "Get information once the app has been launched"
  definition "enable"
  
  output_mappings do {
    $wordpress_url => $wordpress_link
  } end
end

##########################
# DEFINITIONS (i.e. RCL) #
##########################

# Import and set up what is needed for the server and then launch it.
# The server template includes a docker compose input which automatically installs Wordpress
define pre_auto_launch($map_cloud, $param_location, $map_st) do
  
  $cloud_name = map( $map_cloud, $param_location, "cloud" )

  # Check if the selected cloud is supported in this account.
  # Since different PIB scenarios include different clouds, this check is needed.
  # It raises an error if not which stops execution at that point.
  call checkCloudSupport($cloud_name, $param_location)
    
  # Find and import the server template - just in case it hasn't been imported to the account already
  call importServerTemplate($map_st)

end
    
define enable(@docker_server, $param_costcenter, $invSphere, $inAzure) return $wordpress_link do  
    
  # Tag the servers with the selected project cost center ID.
  $tags=[join(["costcenter:id=",$param_costcenter])]
  rs.tags.multi_add(resource_hrefs: @@deployment.servers().current_instance().href[], tags: $tags)
    
  # Get the appropriate IP address depending on the environment.
  if $invSphere
    # Wait for the server to get the IP address we're looking for.
    while equals?(@docker_server.current_instance().private_ip_addresses[0], null) do
      sleep(10)
    end
    $wordpress_server_address =  @docker_server.current_instance().private_ip_addresses[0]
  else
    # Wait for the server to get the IP address we're looking for.
    while equals?(@docker_server.current_instance().public_ip_addresses[0], null) do
      sleep(10)
    end
    $wordpress_server_address = @docker_server.current_instance().public_ip_addresses[0]
  end
  
  $wordpress_port = "8080"

  if $inAzure
    # Find the current bindings for the namenode instance and then drill down to find the IP address href
    @bindings = rs.clouds.get(href: @docker_server.current_instance().cloud().href).ip_address_bindings(filter: ["instance_href==" + @docker_server.current_instance().href])
    @binding = select(@bindings, {"private_port":22})
    @ipaddr = @binding.ip_address()
     
     # Create the binding. We are going to use the chosen port - since we can.
     @docker_server.current_instance().cloud().ip_address_bindings().create({"instance_href" : @docker_server.current_instance().href, 
       "public_ip_address_href" : @ipaddr.href, 
       "protocol" : "TCP", 
       "private_port" : $wordpress_port, 
       "public_port" : $wordpress_port})     
  end
  
  $wordpress_link = join(["http://",$wordpress_server_address,":", $wordpress_port])
  
  # For some reason in Azure, the docker containers - esp wordpress - don't get started as expected.
  # Although this has only been seen in Azure we'll force a start in all clouds - just to be safe.
  $script_name = "APP docker services up"
  @script = rs.right_scripts.get(filter: join(["name==",$script_name]))
  $right_script_href=@script.href
  @task = @docker_server.current_instance().run_executable(right_script_href: $right_script_href, inputs: {})
  if @task.summary =~ "failed"
    raise "Failed to run " + $right_script_href + " on server, " + @docker_server.href
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
  else
    $_error_behavior = "skip"
  end
end

