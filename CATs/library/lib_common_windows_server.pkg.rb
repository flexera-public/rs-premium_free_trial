name "LIB - Windows Server declarations"
rs_ca_ver 20161221
short_description "Windows server resource declarations."

package "pft/windows_server_declarations"

import "pft/parameters"
import "pft/mappings"

resource "windows_server", type: "server", copies: $param_numservers do
  name join(['win-',last(split(@@deployment.href,"/")), "-", copy_index()])
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

parameter "param_servertype" do
  category "Deployment Options"
  label "Windows Server Type"
  type "list"
  allowed_values "Windows 2008R2",
    "Windows 2012R2"
  default "Windows 2012R2"
end

parameter "param_username" do 
  category "User Inputs"
  label "Windows Username" 
#  description "Username (will be created)."
  type "string" 
  no_echo "false"
end

parameter "param_password" do 
  category "User Inputs"
  label "Windows Password" 
  description "Minimum at least 8 characters and must contain at least one of each of the following: 
  Uppercase characters, Lowercase characters, Digits 0-9, Non alphanumeric characters [@#\$%^&+=]." 
  type "string" 
  min_length 8
  max_length 32
  # This enforces a stricter windows password complexity in that all 4 elements are required as opposed to just 3.
  allowed_pattern '(?=.*\d)(?=.*[a-z])(?=.*[A-Z])(?=.*[@#$%^&+=])'
  no_echo "true"
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

## In order for this CAT to compile, the parameters passed to map()
## must exist. When this package is consumed, the consuming CAT will
## redefine these

mapping "map_cloud" do 
  like $mappings.map_cloud
end

mapping "map_instancetype" do 
  like $mappings.map_instancetype
end

parameter "param_location" do
  like $parameters.param_location
end

parameter "param_instancetype" do
  like $parameters.param_instancetype
end
  
parameter "param_numservers" do
  like $parameters.param_numservers
end