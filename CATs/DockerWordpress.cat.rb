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
# A quick prototype that layers Docker on a running server launching using the base linux servertemplate.
# It then installs a WordPress container.
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
name 'E) Docker Container with  WordPress'
rs_ca_ver 20160622
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/docker.png) 

Launch a Docker container with WordPress"
long_description "Launch a Docker server and run WordPress and Database containers.\n
\n"

import "pft/parameters"
import "pft/outputs"
import "pft/conditions"
import "pft/mappings"
import "pft/resources"
import "pft/server_templates_utilities"
import "pft/err_utilities"
import "pft/cloud_utilities"
import "pft/permissions"
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
parameter "param_location" do
  like $parameters.param_location
  allowed_values "AWS", "AzureRM", "Google" 
end

parameter "param_costcenter" do 
  like $parameters.param_costcenter
end


################################
# Outputs returned to the user #
################################
output "wordpress_url" do
  label "WordPress Link"
  category "Output"
end

output "vmware_note" do
  like $outputs.vmware_note
end

##############
# MAPPINGS   #
##############
mapping "map_cloud" do
  like $mappings.map_cloud
end

mapping "map_config" do {
  "st" => {
    "name" => "PFT Base Docker",
    "rev" => "0",
  },
  "mci" => {
    "name" => "PFT Base Linux MCI",
    "rev" => "0",
  },
} end

mapping "map_image_name_root" do 
 like $linux_mappings.map_image_name_root
end

############################
# RESOURCE DEFINITIONS     #
############################

### Server Definition ###
resource "docker_server", type: "server" do
  name join(["DockerServer-",last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
  datacenter map($map_cloud, $param_location, "zone")
  network find(map($map_cloud, $param_location, "network"))
  subnets find(map($map_cloud, $param_location, "subnet"))
  instance_type map($map_cloud, $param_location, "instance_type")
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  placement_group_href map($map_cloud, $param_location, "pg")
  security_group_hrefs map($map_cloud, $param_location, "sg")  
  server_template_href find(map($map_config, "st", "name"), revision: map($map_config, "st", "rev"))
  multi_cloud_image_href find(map($map_config, "mci", "name"), revision: map($map_config, "mci", "rev"))
end

### Security Group Definitions ###
# Note: Even though not all environments need or use security groups, the launch operation/definition will decide whether or not
# to provision the security group and rules.
resource "sec_group", type: "security_group" do
  condition $needsSecurityGroup

  name join(["DockerSecGrp-",last(split(@@deployment.href,"/"))])
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
    "start_port" => "80",
    "end_port" => "80"
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
  like @resources.ssh_key
end

### Placement Group ###
resource "placement_group", type: "placement_group" do
  condition $needsPlacementGroup
  like @resources.placement_group
end 

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
define pre_auto_launch($map_cloud, $map_config, $map_image_name_root, $param_location) do
  
  $cloud_name = map( $map_cloud, $param_location, "cloud" )

  # Check if the selected cloud is supported in this account.
  # Since different PIB scenarios include different clouds, this check is needed.
  # It raises an error if not which stops execution at that point.
  call cloud_utilities.checkCloudSupport($cloud_name, $param_location)
  
  # For some clouds we check if the image is deprecated and if so, update the MCI to use the latest version.
  call mci.updateImage($cloud_name, $param_location, map($map_config, "mci", "name"))
  
  # Set things up for docker stuff
  $inp = {
    "PACKAGES":"text:ruby",  
    "DOCKER_ENVIRONMENT" : "text:mysql:\r\n  MYSQL_ROOT_PASSWORD: example\r\nwordpress:\r\n  WORDPRESS_DB_HOST: mysql\r\n  WORDPRESS_DB_USER: root\r\n  WORDPRESS_DB_PASSWORD: example",
    "DOCKER_SERVICES" : "text:wordpress:\r\n  image: wordpress\r\n  restart: always\r\n  depends_on:\r\n    - mysql\r\n  ports:\r\n    - \"80:80\"\r\nmysql:\r\n  image: mariadb"
  } 
  @@deployment.multi_update_inputs(inputs: $inp)

end
    
define enable(@docker_server, $param_costcenter, $invSphere, $inAzure, $param_location, $map_cloud) return $wordpress_link do  
    
  call server_templates_utilities.run_script_no_inputs(@docker_server, "APP docker services compose")
  call server_templates_utilities.run_script_no_inputs(@docker_server, "APP docker services up")
  
  # Tag the servers with the selected project cost center ID.
  # The tagging API requires an array of tags and an array of resource hrefs to tag.
  $tags=[join([map($map_cloud, $param_location, "tag_prefix"),":costcenter=",$param_costcenter])]
  $instance_hrefs = @@deployment.servers().current_instance().href[]
  # One would normally just pass the entire instance_hrefs[] array to multi_add and so it all in one command.
  # However, the call to the Azure API will at times take too long and time out.
  # So tagging one resource at a time avoids this problem and doesn't add any discernible time to the processing.
  foreach $instance_href in $instance_hrefs do
    rs_cm.tags.multi_add(resource_hrefs: [$instance_href], tags: $tags)
  end
    
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
    
  $wordpress_link = join(["http://",$wordpress_server_address])

end

# Imports and runs all the scripts that are needed to make it a docker host
#define make_it_a_docker_host(@docker_server) do
#  $docker_rightscripts = [ "SYS Packages Install", "SYS Swap Setup", "SYS Swap Setup", "SYS docker-compose install latest", "SYS docker engine install latest", "SYS docker TCP enable", "RL10 Linux Enable Docker Support (Beta)", "APP docker services compose", "APP docker services up" ]
#  foreach $docker_rs in $docker_rightscripts do
#    @pub_rightscript = last(rs_cm.publications.index(filter: ["name=="+$docker_rs]))
#    @pub_rightscript.import()
#    call server_templates_utilities.run_script_no_inputs(@docker_server, $docker_rs)
#  end
#end

