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
# Deploys a basic Linux server of type CentOS or Ubuntu as selected by user.
# It automatically imports the ServerTemplate it needs.
# Also, if needed by the target cloud, the security group and/or ssh key is automatically created by the CAT.


# Required prolog
name 'A) Corporate Standard Linux'
rs_ca_ver 20160622
short_description "![Linux](https://s3.amazonaws.com/rs-pft/cat-logos/linux_logo.png)\n
Get a Linux Server VM in any of our supported public or private clouds"
long_description "Launches a Linux server, defaults to Ubuntu.\n
\n
Clouds Supported: <B>AWS, Azure, Google, VMware</B>"

import "common/parameters"
import "common/mappings"
import "common/resources"
import "common/conditions"
import "util/server_templates"
import "util/clouds"

##################
# User inputs    #
##################
parameter "param_location" do
  like $parameters.param_location
end

parameter "param_servertype" do
  category "User Inputs"
  label "Linux Server Type"
  type "list"
  description "Type of Linux server to launch"
  allowed_values "CentOS", 
    "Ubuntu"
  default "Ubuntu"
end

parameter "param_instancetype" do
  like $parameters.param_instancetype
end

parameter "param_costcenter" do 
  like $parameters.param_costcenter
end

################################
# Outputs returned to the user #
################################
output "ssh_link" do
  label "SSH Link"
  category "Output"
  description "Use this string to access your server."
end

output "vmware_note" do
  condition $invSphere
  label "Deployment Note"
  category "Output"
  default_value "Your CloudApp was deployed in a VMware environment on a private network and so is not directly accessible. If you need access to the CloudApp, please contact your RightScale rep for network access."
end

output "ssh_key_info" do
  condition $inAzure
  label "Link to your SSH Key"
  category "Output"
  description "Use this link to download your SSH private key and use it to login to the server using provided \"SSH Link\"."
  default_value "https://my.rightscale.com/global/users/ssh#ssh"
end


##############
# MAPPINGS   #
##############
mapping "map_cloud" do 
  like $mappings.map_cloud
end

mapping "map_instancetype" do {
  like $mappings.map_instancetype
end

mapping "map_st" do {
  "linux_server" => {
    "name" => "Base ServerTemplate for Linux (RSB) (v14.1.1)",
    "rev" => "18",
  },
} end

mapping "map_mci" do {
  "VMware" => { # vSphere 
    "CentOS_mci" => "RightImage_CentOS_6.6_x64_v14.2_VMware",
    "CentOS_mci_rev" => "9",
    "Ubuntu_mci" => "RightImage_Ubuntu_14.04_x64_v14.2_VMware",
    "Ubuntu_mci_rev" => "7"
  },
  "Public" => { # all other clouds
    "CentOS_mci" => "RightImage_CentOS_6.6_x64_v14.2",
    "CentOS_mci_rev" => "24",
    "Ubuntu_mci" => "RightImage_Ubuntu_14.04_x64_v14.2",
    "Ubuntu_mci_rev" => "11"
  }
} end


############################
# RESOURCE DEFINITIONS     #
############################

### Server Definition ###
resource "linux_server", type: "server" do
  name join(['Linux Server-',last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
  datacenter map($map_cloud, $param_location, "zone")
  instance_type map($map_instancetype, $param_instancetype, $param_location)
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  placement_group_href map($map_cloud, $param_location, "pg")
  security_group_hrefs map($map_cloud, $param_location, "sg")  
  server_template_href find(map($map_st, "linux_server", "name"), revision: map($map_st, "linux_server", "rev"))
  multi_cloud_image_href find(map($map_mci, map($map_cloud, $param_location, "mci_mapping"), join([$param_servertype, "_mci"])), revision: map($map_mci, map($map_cloud, $param_location, "mci_mapping"), join([$param_servertype, "_mci_rev"])))
  inputs do {
    "SECURITY_UPDATES" => "text:enable" # Enable security updates
  } end
end

### Security Group Definitions ###
# Note: Even though not all environments need or use security groups, the launch operation/definition will decide whether or not
# to provision the security group and rules.
resource "sec_group", type: "security_group" do
  condition $needsSecurityGroup
  like @resources.sec_group
end

resource "sec_group_rule_ssh", type: "security_group_rule" do
  condition $needsSecurityGroup
  like @resources.sec_group_rule_ssh
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
# Permissions    #
##################
permission "import_servertemplates" do
  like $server_templates.import_servertemplates
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
  
  # Update the links provided in the outputs.
  output_mappings do {
    $ssh_link => $server_ip_address,
  } end
end

##########################
# DEFINITIONS (i.e. RCL) #
##########################

# Import and set up what is needed for the server and then launch it.
define pre_auto_launch($map_cloud, $param_location, $invSphere, $map_st) do
  

    # Need the cloud name later on
    $cloud_name = map( $map_cloud, $param_location, "cloud" )

    # Check if the selected cloud is supported in this account.
    # Since different PIB scenarios include different clouds, this check is needed.
    # It raises an error if not which stops execution at that point.
    call cloud.checkCloudSupport($cloud_name, $param_location)
    
    # Find and import the server template - just in case it hasn't been imported to the account already
    call server_templates.importServerTemplate($map_st)

end

define enable(@linux_server, $param_costcenter, $inAzure, $invSphere) return $server_ip_address do
  
    # Tag the servers with the selected project cost center ID.
    $tags=[join(["costcenter:id=",$param_costcenter])]
    rs_cm.tags.multi_add(resource_hrefs: @@deployment.servers().current_instance().href[], tags: $tags)
    
    # Get the appropriate IP address depending on the environment.
    if $invSphere
      # Wait for the server to get the IP address we're looking for.
      while equals?(@linux_server.current_instance().private_ip_addresses[0], null) do
        sleep(10)
      end
      $server_addr =  @linux_server.current_instance().private_ip_addresses[0]
    else
      # Wait for the server to get the IP address we're looking for.
      while equals?(@linux_server.current_instance().public_ip_addresses[0], null) do
        sleep(10)
      end
      $server_addr =  @linux_server.current_instance().public_ip_addresses[0]
    end 

    # If deployed in Azure one needs to provide the port mapping that Azure uses.
    if $inAzure
       @bindings = rs_cm.clouds.get(href: @linux_server.current_instance().cloud().href).ip_address_bindings(filter: ["instance_href==" + @linux_server.current_instance().href])
       @binding = select(@bindings, {"private_port":22})
       $server_ip_address = join(["-p ", @binding.public_port, " rightscale@", to_s(@linux_server.current_instance().public_ip_addresses[0])])
    else
      # If not in Azure, then we can actually provide the SSH link like that found in CM.
      $server_ip_address = join(["ssh://rightscale@", $server_addr])
    end
end 

