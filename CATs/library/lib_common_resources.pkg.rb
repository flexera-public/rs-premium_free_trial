name "LIB - Common resources"
rs_ca_ver 20160622
short_description "Resources that are commonly used across CATs"

package "pft/resources"

import "pft/parameters"
import "pft/mappings"
import "pft/conditions"

### Security Group Definitions ###
# Note: Even though not all environments need or use security groups, the launch operation/definition will decide whether or not
# to provision the security group and rules.
resource "sec_group", type: "security_group" do
  name join(["SecGrp-",last(split(@@deployment.href,"/"))])
  description "Server security group."
  cloud map( $map_cloud, $param_location, "cloud" )
end

resource "sec_group_rule_ssh", type: "security_group_rule" do
  name join(["SshRule-",last(split(@@deployment.href,"/"))])
  description "Allow SSH access."
  source_type "cidr_ips"
  security_group @sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "22",
    "end_port" => "22"
  } end
end

resource "sec_group_rule_rdp", type: "security_group_rule" do
  name join(["RdpRule-",last(split(@@deployment.href,"/"))])
  description "Allow RDP access."
  source_type "cidr_ips"
  security_group @sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "3389",
    "end_port" => "3389"
  } end
end

### SSH key declarations ###
resource "ssh_key", type: "ssh_key" do
  name join(["sshkey_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
end

### Placement group declaration ###
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