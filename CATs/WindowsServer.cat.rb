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
# Deploys a Windows Server of the type chosen by the user.
# It automatically imports the ServerTemplate it needs.

# Required prolog
name 'B) Corporate Standard Windows Server'
rs_ca_ver 20161221
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/windows.png) 

Get a Windows Server VM in a our supported public clouds."
long_description "Allows you to select different windows server types and cloud and performance level you want.\n
\n
Clouds Supported: <B>AWS, AzureRM, Google</B>"

import "pft/parameters"
import "pft/mappings"
import "pft/resources", as: "common_resources"
import "pft/conditions"
import "pft/server_templates_utilities"
import "pft/cloud_utilities"
import "pft/account_utilities"
import "pft/err_utilities", as: "debug"

##################
# User inputs    #
##################

parameter "param_location" do
  like $parameters.param_location
  allowed_values "AWS", "AzureRM", "Google"
  default "AWS"
end

parameter "param_servertype" do
  category "Deployment Options"
  label "Windows Server Type"
  type "list"
  allowed_values "Windows 2008R2",
    "Windows 2012R2"
  default "Windows 2012R2"
end

parameter "param_instancetype" do
  like $parameters.param_instancetype
end

parameter "param_costcenter" do 
  category "User Inputs"
  like $parameters.param_costcenter
end


################################
# Outputs returned to the user #
################################
output "output_server_ip" do
  label "Server IP"
  category "Output"
  description "IP address for the server."
  default_value @windows_server.public_ip_address
end

output "output_win_username" do
  label "Windows User Name"
  category "Output"
  description "Admin user name for the server."
end

output "output_win_credname" do
  label "Windows Password Credential Name" 
  category "Output"
  description "Name to Credential Storing Windows Password"
end

output "output_win_cred_uri" do
  label "Windows Password Credential Link" 
  category "Output"
  description "Link to Credential Storing Windows Password"
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

mapping "map_st" do {
  "windows_server" => {
    "name" => "PFT Base Windows ServerTemplate",
    "rev" => "latest",
  },
} end

# The off-the-shelf ServerTemplate being used has a couple of different MCIs defined based on the cloud.   
mapping "map_mci" do {
  "Windows 2008R2" => {  # Same MCI for all 3 environments
    "mci" => "PFT Windows_Server_2008R2_x64",
  },
  "Windows 2012R2" => { # Different MCI for AWS vs ARM and not supported for Google so substituting an R2 version
    "mci" => "PFT Windows_Server_2012R2_x64",
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

### Server Definition ###
resource "windows_server", type: "server" do
  name join(['win',last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
  datacenter map($map_cloud, $param_location, "zone")
  network find(map($map_cloud, $param_location, "network"))
  subnets find(map($map_cloud, $param_location, "subnet"))
  server_template_href find(map($map_st, "windows_server", "name"))
  multi_cloud_image_href find(map($map_mci, $param_servertype, "mci"))
  instance_type map($map_instancetype, $param_instancetype, $param_location)
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  security_group_hrefs map($map_cloud, $param_location, "sg")  
  placement_group_href map($map_cloud, $param_location, "pg")
end
  

### Security Group Definitions ###
# Note: Even though not all environments need or use security groups, the launch operation/definition will decide whether or not
# to provision the security group and rules.
resource "sec_group", type: "security_group" do
  condition $needsSecurityGroup
  like @common_resources.sec_group
end

resource "sec_group_rule_rdp", type: "security_group_rule" do
  condition $needsSecurityGroup
  like @common_resources.sec_group_rule_rdp
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
# Permissions    #
##################
permission "import_servertemplates" do
  like $server_templates_utilities.import_servertemplates
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
     $output_win_username => $win_username,
     $output_win_credname => $credname,
     $output_win_cred_uri => $cred_uri
   } end
end

operation "terminate" do
  description "clean up before auto terminate"
  definition "pre_auto_terminate"
end


##########################
# DEFINITIONS (i.e. RCL) #
##########################

# Import and set up what is needed for the server and then launch it.
define pre_auto_launch($map_cloud, $param_location, $map_st) do
    
  # Need the cloud name later on
  $cloud_name = map( $map_cloud, $param_location, "cloud" )

  # Check if the selected cloud is supported in this account.
  # Since different PIB scenarios include different clouds, this check is needed.
  # It raises an error if not which stops execution at that point.
  call cloud_utilities.checkCloudSupport($cloud_name, $param_location)

end

define enable(@windows_server, $param_costcenter, $param_location) return $win_username, $credname, $cred_uri do
  
  # Tag the servers with the selected project cost center ID.
  $tags=[join(["costcenter:id=",$param_costcenter])]
  rs_cm.tags.multi_add(resource_hrefs: @@deployment.servers().current_instance().href[], tags: $tags)
    
  # Gather up the generated password and make a credential for it and let the user know where to find it.
  $instance_info = @windows_server.current_instance().get(view: "sensitive")
  $admin_password = $instance_info[0]["admin_password"]
  $credname = join(["CAT_WINDOWS_ADMIN_PASSWORD-",last(split(@@deployment.href,"/"))])
  @cred = rs_cm.credentials.create({"name":$credname, "value": $admin_password})
  
  $cred_num = last(split(@cred.href, "/"))
  call account_utilities.find_account_number() retrieve $account_num
  $cred_uri = "https://my.rightscale.com/acct/"+$account_num+"/credentials/"+$cred_num
  
  $win_username = "administrator"  
  if ($param_location == "AzureRM") 
    $win_username = "rsadministrator" 
  end

end 

# Delete the credential created for the windows password
define pre_auto_terminate() do
  
  # Delete the cred we created for the user-provided password
  $credname = join(["CAT_WINDOWS_ADMIN_PASSWORD-",last(split(@@deployment.href,"/"))])
  @cred=rs_cm.credentials.get(filter: [join(["name==",$credname])])
  @cred.destroy()
  
end

