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
# Deploys a basic Linux server in a cloud of user's choice with a performance profile of user's choice.


# Required prolog
name 'A) Corporate Standard Linux'
rs_ca_ver 20161221
short_description "![Linux](https://s3.amazonaws.com/rs-pft/cat-logos/linux_logo.png)\n
Get a Linux Server VM in any of our supported public or private clouds"
long_description "Launches a Linux server.\n
\n
Clouds Supported: <B>AWS, Azure Classic, AzureRM, Google, VMware</B>"

import "pft/parameters"
import "pft/mappings"
import "pft/resources", as: "common_resources"
import "pft/linux_server_declarations"
import "pft/conditions"
import "pft/cloud_utilities", as: "cloud"
import "pft/account_utilities", as: "account"
import "pft/err_utilities", as: "debug"
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
end

parameter "param_instancetype" do
  like $parameters.param_instancetype
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

output "vmware_note" do
  condition $invSphere
  label "Deployment Note"
  category "Note"
  default_value "Your CloudApp was deployed in a VMware environment on a private network and so is not directly accessible. If you need access to the CloudApp, please contact your RightScale rep for network access."
end

##############
# MAPPINGS   #
##############
mapping "map_cloud" do 
  like $mappings.map_cloud
end

mapping "map_instancetype" do 
  like $mappings.map_instancetype
end

mapping "map_config" do 
  like $linux_server_declarations.map_config
end

mapping "map_image_name_root" do 
 like $linux_mappings.map_image_name_root
end


############################
# RESOURCE DEFINITIONS     #
############################

### Server Definition ###
resource "linux_servers", type: "server", copies: $param_numservers do
  like @linux_server_declarations.linux_server
end

### Security Group Definitions ###
# Note: Even though not all environments need or use security groups, the launch operation/definition will decide whether or not
# to provision the security group and rules.
resource "sec_group", type: "security_group" do
  condition $needsSecurityGroup
  like @common_resources.sec_group
end

resource "sec_group_rule_ssh", type: "security_group_rule" do
  condition $needsSecurityGroup
  like @common_resources.sec_group_rule_ssh
end

### SSH Key ###
resource "ssh_key", type: "ssh_key" do
  condition $needsSshKey
  like @common_resources.ssh_key
end

### Placement Group ###
resource "placement_group", type: "placement_group" do
  condition $needsPlacementGroup
  like @common_resources.placement_group
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

condition "notInVsphere" do
  logic_not($invSphere)
end

condition "inAzure" do
  like $conditions.inAzure
end 

condition "inAzureRM" do
  like $conditions.inAzureRM
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

# Import and set up what is needed for the server and then launch it.
define pre_auto_launch($map_cloud, $map_config, $map_image_name_root, $param_location, $invSphere) do
  
    # Need the cloud name later on
    $cloud_name = map( $map_cloud, $param_location, "cloud" )

    # Check if the selected cloud is supported in this account.
    # Since different PIB scenarios include different clouds, this check is needed.
    # It raises an error if not which stops execution at that point.
    call cloud.checkCloudSupport($cloud_name, $param_location)
  
    # For some clouds we check if the image is deprecated and if so, update the MCI to use the latest version.
    call mci.updateImage($cloud_name, $param_location, map($map_config, "mci", "name"))
     
end

define enable(@linux_servers, $param_costcenter, $inAzure, $invSphere, $param_location, $map_cloud) return @servers, $server_ips do
  
    # Tag the servers with the selected project cost center ID.
    $tags=[join([map($map_cloud, $param_location, "tag_prefix"),":costcenter=",$param_costcenter])]
    $instance_hrefs = @@deployment.servers().current_instance().href[]
    # One would normally just pass the entire instance_hrefs[] array to multi_add and so it all in one command.
    # However, the call to the Azure API will at times take too long and time out.
    # So tagging one resource at a time avoids this problem and doesn't add any discernible time to the processing.
    foreach $instance_href in $instance_hrefs do
      rs_cm.tags.multi_add(resource_hrefs: [$instance_href], tags: $tags)
    end    
    
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

