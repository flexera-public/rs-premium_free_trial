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
rs_ca_ver 20131202
short_description "![Linux](https://s3.amazonaws.com/rs-pft/cat-logos/linux_logo.png)\n
Get a Linux Server VM in any of our supported public or private clouds"
long_description "Launches a Linux server.\n
\n
Clouds Supported: <B>AWS, Azure, AzureRM, Google, VMware</B>"

##################
# User inputs    #
##################
parameter "param_location" do 
  category "User Inputs"
  label "Cloud" 
  type "string" 
  description "Cloud to deploy in." 
  allowed_values "AWS", "Azure", "AzureRM", "Google", "VMware"
  default "Google"
end

#parameter "param_servertype" do
#  category "User Inputs"
#  label "Linux Server Type"
#  type "list"
#  description "Type of Linux server to launch"
#  allowed_values "CentOS", 
#    "Ubuntu"
#  default "Ubuntu"
#end

parameter "param_instancetype" do
  category "User Inputs"
  label "Server Performance Level"
  type "list"
  description "Server performance level"
  allowed_values "standard performance",
    "high performance"
  default "standard performance"
end

parameter "param_costcenter" do 
  category "User Inputs"
  label "Cost Center" 
  type "string" 
  allowed_values "Development", "QA", "Production"
  default "Development"
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

#output "ssh_key_info" do
#  condition $inAzure
#  label "Link to your SSH Key"
#  category "Output"
#  description "Use this link to download your SSH private key and use it to login to the server using provided \"SSH Link\"."
#  default_value "https://my.rightscale.com/global/users/ssh#ssh"
#end


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
    "st_mapping" => "v14",
    "mci_mapping" => "Public",
    "network" => null,
    "subnets" => null
  },
  "Azure" => {   
    "cloud" => "Azure East US",
    "zone" => null,
    "instance_type" => "D1",
    "sg" => null, 
    "ssh_key" => null,
    "pg" => "@placement_group",
    "st_mapping" => "v14",
    "mci_mapping" => "Public",
    "network" => null,
    "subnets" => null
  },
  "AzureRM" => {   
    "cloud" => "AzureRM East US",
    "zone" => null,
    "instance_type" => "D1",
    "sg" => null, 
    "ssh_key" => null,
    "pg" => null,
    "st_mapping" => "rl10",
    "mci_mapping" => "rl10",
    "network" => "@arm_network",
    "subnets" => "default"
  },
  "Google" => {
    "cloud" => "Google",
    "zone" => "us-central1-c", # launches in Google require a zone
    "instance_type" => "n1-standard-2",
    "sg" => '@sec_group',  
    "ssh_key" => null,
    "pg" => null,
    "st_mapping" => "v14",
    "mci_mapping" => "Public",
    "network" => null,
    "subnets" => null
  },
  "VMware" => {
    "cloud" => "VMware Private Cloud",
    "zone" => "VMware_Zone_1", # launches in vSphere require a zone being specified  
    "instance_type" => "large",
    "sg" => null, 
    "ssh_key" => "@ssh_key",
    "pg" => null,
    "st_mapping" => "v14",
    "mci_mapping" => "VMware",
    "network" => null,
    "subnets" => null
  }
}
end

mapping "map_instancetype" do {
  "standard performance" => {
    "AWS" => "m3.medium",
    "Azure" => "D1",
    "AzureRM" => "D1",
    "Google" => "n1-standard-1",
    "VMware" => "small",
  },
  "high performance" => {
    "AWS" => "m3.large",
    "Azure" => "D2",
    "AzureRM" => "D2",
    "Google" => "n1-standard-2",
    "VMware" => "large",
  }
} end

mapping "map_st" do {
  "v14" => {
    "name" => "Base ServerTemplate for Linux (RSB) (v14.1.1)",
    "rev" => "18",
  },
  "rl10" => {
    "name" => "RightLink 10.5.1 Linux Base",
    "rev" => "69",
  },
} end

mapping "map_mci" do {
  "VMware" => { # vSphere 
    "Ubuntu_mci" => "RightImage_Ubuntu_14.04_x64_v14.2_VMware",
    "Ubuntu_mci_rev" => "7"
  },
  "Public" => { # all other clouds
    "Ubuntu_mci" => "RightImage_Ubuntu_14.04_x64_v14.2",
    "Ubuntu_mci_rev" => "11"
  }, 
  "rl10" => { # all other clouds
    "Ubuntu_mci" => "Ubuntu_14.04_x64",
    "Ubuntu_mci_rev" => "49"
  }
} end




############################
# RESOURCE DEFINITIONS     #
############################
### Network Definitions ###
# Only needed for ARM where since PFT CATs need to be self-sufficient and portable we can't assume it already has a default network defined.
resource "arm_network", type: "network" do
  condition $inArm
  name join(["cat_vpc_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
  cidr_block "192.168.164.0/24"
end

### Server Definition ###
# We have two server definitions. One is used if launching in anywhere other than ARM.
# The other is for ARM launches. ARM gets special treatment since in the interest of being able to share these PFT CATs, 
# we need to create the network. This then drives differences in the server definition. 
# In a production scenario this PFT CAT "self-sufficiency" rule would likely not exist. 
resource "linux_server", type: "server" do
  condition $notInArm
  name join(['Linux Server-',last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
  datacenter map($map_cloud, $param_location, "zone")
  network map($map_cloud, $param_location, "network")
  subnets map($map_cloud, $param_location, "subnets")
  instance_type map($map_instancetype, $param_instancetype, $param_location)
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  placement_group_href map($map_cloud, $param_location, "pg")
  security_group_hrefs map($map_cloud, $param_location, "sg")  
  server_template_href find(map($map_st, map($map_cloud, $param_location, "st_mapping"), "name"), revision: map($map_st, map($map_cloud, $param_location, "st_mapping"), "rev"))
  multi_cloud_image_href find(map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "Ubuntu_mci"), revision: map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "Ubuntu_mci_rev"))
end

resource "arm_linux_server", type: "server" do
  condition $inArm
  like @linux_server
  name join(['Linux Server-',last(split(@@deployment.href,"/"))])
  network @arm_network
  subnets find("default", network_href: @arm_network)
end

### Security Group Definitions ###
# Note: Even though not all environments need or use security groups, the launch operation/definition will decide whether or not
# to provision the security group and rules.
resource "sec_group", type: "security_group" do
  condition $needsSecurityGroup

  name join(["LinuxServerSecGrp-",last(split(@@deployment.href,"/"))])
  description "Linux Server security group."
  cloud map( $map_cloud, $param_location, "cloud" )
end

resource "sec_group_rule_ssh", type: "security_group_rule" do
  condition $needsSecurityGroup

  name join(["Linux server SSH Rule-",last(split(@@deployment.href,"/"))])
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
  logic_or(logic_or(equals?($param_location, "AWS"), equals?($param_location, "Google")), equals?($param_location, "AzureRM"))
end

condition "invSphere" do
  equals?($param_location, "VMware")
end

condition "inAzure" do
  equals?($param_location, "Azure")
end

condition "inArm" do
  equals?($param_location, "AzureRM")
end

condition "notInArm" do
  logic_not(equals?($param_location, "AzureRM"))
end

condition "needsPlacementGroup" do
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
  
  # Update the links provided in the outputs.
  output_mappings do {
    $ssh_link => $server_ip_address,
  } end
end

# For ARM, we want to explicitly terminate the server before the networks are cleaned up
operation "terminate" do 
  condition $inArm
  description "Terminate the server"
  definition "arm_terminate"
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
    call checkCloudSupport($cloud_name, $param_location)
    
    # Find and import the server template - just in case it hasn't been imported to the account already
    call importServerTemplate($map_st)

end

define enable($param_costcenter, $invSphere, $inAzure, $inArm) return $server_ip_address do
  
  call tag_it($param_costcenter)
  
  call get_server_ssh_link($invSphere, $inAzure, $inArm) retrieve $server_ip_address
  
end

# In ARM I want to delete the server before auto-terminate tries to delete the networks and stuff.
define arm_terminate(@arm_linux_server) do
  delete(@arm_linux_server)
end

  
define tag_it($param_costcenter) do
    # Tag the servers with the selected project cost center ID.
    $tags=[join(["costcenter:id=",$param_costcenter])]
    rs.tags.multi_add(resource_hrefs: @@deployment.servers().current_instance().href[], tags: $tags)
end

define get_server_ssh_link($invSphere, $inAzure, $inArm) return $server_ip_address do
  
  # Find the instance in the deployment
  @linux_server = @@deployment.servers()
    
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
    
    $username = "rightscale"
    if $inArm
      call getUserLogin() retrieve $username
    end

    $server_ip_address = "ssh://"+ $username + "@" + $server_addr
    
    # If in Azure classic then there are some port bindings that need to be reflected in the SSH link
    if $inAzure
       @bindings = rs.clouds.get(href: @linux_server.current_instance().cloud().href).ip_address_bindings(filter: ["instance_href==" + @linux_server.current_instance().href])
       @binding = select(@bindings, {"private_port":22})
       $server_ip_address = $server_ip_address + ":" + @binding.public_port
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

# Used for retry mechanism
define handle_retries($attempts) do
  if $attempts < 3
    $_error_behavior = "retry"
    sleep(60)
  else
    $_error_behavior = "skip"
  end
end

define getUserLogin() return $userlogin do

  $deployment_description_array = lines(@@deployment.description)
  $userid="tbd"
  foreach $entry in $deployment_description_array do
    if include?($entry, "Author")
      $userid = split(split(lstrip(split(split($entry, ":")[1], "(")[0]), '[`')[1],'`]')[0]
    end
  end

  $userlogin = rs.users.get(filter: "email=="+$userid).login_name

end




