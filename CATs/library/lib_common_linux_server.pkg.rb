name "LIB - Linux Server declarations"
rs_ca_ver 20161221
short_description "Linux server resource declarations."

package "pft/linux_server_declarations"

import "pft/parameters"
import "pft/mappings"

resource "linux_server", type: "server", copies: $param_numservers do
  name join(['linux-',last(split(@@deployment.href,"/")), "-", copy_index()])
  cloud map($map_cloud, $param_location, "cloud")
  datacenter map($map_cloud, $param_location, "zone")
  network find(map($map_cloud, $param_location, "network"))
  subnets find(map($map_cloud, $param_location, "subnet"))
  instance_type map($map_instancetype, $param_instancetype, $param_location)
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  placement_group_href map($map_cloud, $param_location, "pg")
  security_group_hrefs map($map_cloud, $param_location, "sg")  
  server_template_href find(map($map_config, "st", "name"), revision: map($map_config, "st", "rev"))
  multi_cloud_image_href find(map($map_config, "mci", "name"), revision: map($map_config, "mci", "rev"))
end

mapping "map_config" do {
  "st" => {
    "name" => "PFT Base Linux ServerTemplate",
    "rev" => "0",
  },
  "mci" => {
    "name" => "PFT Base Linux MCI",
    "rev" => "0",
  },
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

