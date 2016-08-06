# Required prolog
name 'Linux Server - ARM with Network Creation'
rs_ca_ver 20160622
short_description "ARM server with network creation"


################################
# Outputs returned to the user #
################################
output "ssh_link" do
  label "SSH Link"
  category "Output"
  description "Use this string to access your server."
end


############################
# RESOURCE DEFINITIONS     #
############################

### Network Definitions ###
resource "arm_network", type: "network" do
  name join(["cat_vpc_", last(split(@@deployment.href,"/"))])
  cloud "AzureRM East US"
  cidr_block "192.168.164.0/24"
end

#resource "arm_subnet", type: "subnet" do
#  name join(["cat_subnet_", last(split(@@deployment.href,"/"))])
#  cloud "AzureRM East US"
#  network_href @arm_network
#  cidr_block "192.168.164.0/28"
#end


### Server Definition ###
resource "linux_server", type: "server" do
  name 'Linux Server'
  cloud "AzureRM East US"
  network @arm_network
  subnets find("default", network_href: @arm_network)
  instance_type "D2"
  security_group_hrefs @sec_group 
  server_template_href find("RightLink 10.5.1 Linux Base", revision: 69)
  multi_cloud_image_href find("Ubuntu_14.04_x64", revision: 49)
end

### Security Group Definitions ###
# Note: Even though not all environments need or use security groups, the launch operation/definition will decide whether or not
# to provision the security group and rules.
resource "sec_group", type: "security_group" do
  name join(["cat_arm_sg_", last(split(@@deployment.href,"/"))])
  description "Linux Server security group."
  cloud "AzureRM East US"
  network @arm_network
end

resource "sec_group_rule_ssh", type: "security_group_rule" do
  name join(["cat_arm_sshrule_", last(split(@@deployment.href,"/"))])
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

#operation "launch" do 
#  description "Launch the server"
#  definition "pre_auto_launch"
#end
#
#define pre_auto_launch(@arm_network) return @arm_network do
#  
#  # create network and wait for default subnet to be created
#  provision(@arm_network)
#  
#  @default_subnet = find("subnets", {name: "default", network_href: @arm_network})
#  while empty?(@default_subnet) do
#    sleep(5)
#    @default_subnet = find("subnets", {name: "default", network_href: @arm_network})
#  end
#  
#end
