name "LIB - Common resources"
rs_ca_ver 20160622
short_description "Resources that are commonly used across CATs"

package "common/resources"

import "common/parameters"
import "common/mappings"
import "common/conditions"

resource "ssh_key", type: "ssh_key" do
  name join(["sshkey_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
end

resource "placement_group", type: "placement_group" do
  name last(split(@@deployment.href,"/"))
  cloud map($map_cloud, $param_location, "cloud")
end 


## In order for this CAT to compile, the parameters passed to map()
## must exist. When this package is consumed, the consuming CAT will
## redefine these

mapping "map_cloud" do 
  like $mappings.map_cloud
end

parameter "param_location" do
  like $parameters.param_location
end

condition "needsSshKey" do
  like $conditions.needsSshKey
end

condition "needsPlacementGroup" do
  like $conditions.needsPlacementGroup
end