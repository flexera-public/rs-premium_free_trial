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
# Deploys a Rancher Docker cluster consisting of a Rancher Server and any number of Rancher Hosts.
# 
# FEATURES
# User can select cloud.
# User can select number of Rancher Hosts to launch.
# User can scale out additional Rancher Hosts after launch.
#
# TO-DOs
# Have link go straight to infrastructure in Rancher
# Add post launch actions to launch some services from Self-Service More Actions menu.
# Store the API keys in CREDENIALs and use cred: in inputs instead of current clear text approach.
# Allow user to scale out more hosts after launch. (I'm not convinced there is a safe way to allow scaling in.)
# Support more clouds. This would require coordinating with the ST author to add images in other clouds.

name 'Rancher Cluster'
rs_ca_ver 20131202
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/rancher_logo.jpg) ![logo](https://s3.amazonaws.com/rs-pft/cat-logos/docker.png)

Launches a Rancher cluster of Docker hosts."
long_description "Launches a Rancher cluster.\n
Clouds Supported: <B>AWS, Google</B>"

##################
# User inputs    #
##################
parameter "param_location" do 
  category "Deployment Options"
  label "Cloud" 
  type "string" 
  allowed_values "AWS", "Google" 
  default "AWS"
end

parameter 'param_qty' do
  category "Deployment Options"
  type 'number'
  label 'Number of Rancher Hosts'
  description 'Enter a value from 1 to 4.'
  min_value 1
  max_value 4
  default 1
end

################################
# Outputs returned to the user #
################################
output "rancher_ui_link" do
  label "Rancher UI"
  category "Rancher UI Access"
  description "Click to access the Rancher UI."
end

[*1..10].each do |n|
  output "app_#{n}_name" do
    label "Application #{n} Name"
    category "Application Stacks"
  end
end

[*1..10].each do |n|
  output "app_#{n}_link" do
    label "Application #{n} link"
    category "Application Stacks"
  end
end

##############
# MAPPINGS   #
##############

# Mapping and abstraction of cloud-related items.
mapping "map_cloud" do {
  "AWS" => {
    "cloud" => "EC2 us-west-1",
    "zone" => null, # We don't care which az AWS decides to use.
    "instance_type" => "m3.medium",
    "sg" => '@sec_group',  
    "ssh_key" => "@ssh_key",
    "pg" => null,
    "mci_mapping" => "Public",
  },
  "Azure" => {   
    "cloud" => "Azure East US",
    "zone" => null,
    "instance_type" => "medium",
    "sg" => null, 
    "ssh_key" => null,
    "pg" => "@placement_group",
    "mci_mapping" => "Public",
  },
  "Google" => {
    "cloud" => "Google",
    "zone" => "us-central1-c", # launches in Google require a zone
    "instance_type" => "n1-standard-2",
    "sg" => '@sec_group',  
    "ssh_key" => null,
    "pg" => null,
    "mci_mapping" => "Public",
  },
  "VMware" => {
    "cloud" => "POC vSphere",
    "zone" => "POC-vSphere-Zone-1", # launches in vSphere require a zone being specified  
    "instance_type" => "large",
    "sg" => null, 
    "ssh_key" => "@ssh_key",
    "pg" => null,
    "mci_mapping" => "VMware",
  }
}
end

# Mapping of which ServerTemplates and Revisions to use for each tier.
mapping "map_st" do {
  "server" => {
    "name" => "Rancher Server",
    "rev" => "17",
  },
  "host" => {
    "name" => "Rancher Host",
    "rev" => "7", 
  },
} end

mapping "map_mci" do {
  "VMware" => { # vSphere 
    "mci_name" => "NA",
    "mci_rev" => "NA",
  },
  "Public" => { # all other clouds
    "mci_name" => "Ubuntu_14.04_x64",
    "mci_rev" => "13",
  }
} end



##################
# CONDITIONS     #
##################

# Used to decide whether or not to pass an SSH key or security group when creating the servers.
condition "needsSshKey" do
  logic_or(equals?($param_location, "AWS"), equals?($param_location, "VMware"))
end

condition "needsSecurityGroup" do
  logic_or(equals?($param_location, "AWS"), equals?($param_location, "Google"))
end

condition "needsPlacementGroup" do
  equals?($param_location, "Azure")
end

condition "invSphere" do
  equals?($param_location, "VMware")
end

condition "inAzure" do
  equals?($param_location, "Azure")
end

############################
# RESOURCE DEFINITIONS     #
############################

### Server Declarations ###
resource 'rancher_server', type: 'server' do
  name 'Rancher Server'
  cloud map( $map_cloud, $param_location, "cloud" )
  datacenter map($map_cloud, $param_location, "zone")
  instance_type map($map_cloud, $param_location, "instance_type")
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  placement_group_href map($map_cloud, $param_location, "pg")
  security_group_hrefs map($map_cloud, $param_location, "sg") 
  server_template find(map($map_st, "server", "name"), revision: map($map_st, "server", "rev"))
  multi_cloud_image_href find(map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_name"), revision: map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_rev"))
end

resource 'rancher_host', type: 'server_array' do
  name 'Rancher Host'
  cloud map( $map_cloud, $param_location, "cloud" )
  datacenter map($map_cloud, $param_location, "zone")
  instance_type map($map_cloud, $param_location, "instance_type")
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  placement_group_href map($map_cloud, $param_location, "pg")
  security_group_hrefs map($map_cloud, $param_location, "sg") 
  server_template find(map($map_st, "host", "name"), revision: map($map_st, "host", "rev"))
  multi_cloud_image_href find(map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_name"), revision: map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_rev"))
  # Server Array Settings
  state "enabled"
  array_type "alert"
  elasticity_params do {
    "bounds" => {
      "min_count"            => $param_qty,
      "max_count"            => 4
    },
    "pacing" => {
      "resize_calm_time"     => 5, 
      "resize_down_by"       => 1,
      "resize_up_by"         => 1
    },
    "alert_specific_params" => {
      "decision_threshold"   => 51,
      "voters_tag_predicate" => "Rancher Host"
    }
  } end
end

resource "sec_group", type: "security_group" do
  name join(["sec_group-",@@deployment.href])
  description "CAT security group."
  cloud map( $map_cloud, $param_location, "cloud" )
end

# Needed for Rancher UI and API access.
resource "sec_group_rule_http8080", type: "security_group_rule" do
  name "CAT HTTP 8080 Rule"
  description "Allow HTTP port 8080 access."
  source_type "cidr_ips"
  security_group @sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "8080",
    "end_port" => "8080"
  } end
end

# Nice to have for stacks launched on the cluster.
resource "sec_group_rule_http80", type: "security_group_rule" do
  name "CAT HTTP 80 Rule"
  description "Allow HTTP port 80 access."
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

# Nice to have for stacks launched on the cluster.
resource "sec_group_rule_http443", type: "security_group_rule" do
  name "CAT HTTP 443 Rule"
  description "Allow HTTP port 443 access."
  source_type "cidr_ips"
  security_group @sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "443",
    "end_port" => "443"
  } end
end

# Nice to have SSH access for debugging
resource "sec_group_rule_ssh", type: "security_group_rule" do
  name "CAT SSH Rule"
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

# UDP 500 and 4500 is needed for the Rancher overlay ipsec network.
resource "sec_group_rule_udp500", type: "security_group_rule" do
  name "CAT UDP 500 Rule"
  description "Allow UDP port 500 access."
  source_type "cidr_ips"
  security_group @sec_group
  protocol "udp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "500",
    "end_port" => "500"
  } end
end

resource "sec_group_rule_udp4500", type: "security_group_rule" do
  name "CAT UDP 500 Rule"
  description "Allow UDP port 4500 access."
  source_type "cidr_ips"
  security_group @sec_group
  protocol "udp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "4500",
    "end_port" => "44500"
  } end
end

### SSH Key ###
resource "ssh_key", type: "ssh_key" do
  name join(["sshkey_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
end


##################
# Permissions    #
##################
permission "import_servertemplates" do
  actions   "rs.import"
  resources "rs.publications"
end

####################
# OPERATIONS       #
####################
operation 'launch' do 
  description 'Launch the application' 
  definition 'launch_cluster' 
  output_mappings do {
    $rancher_ui_link => $rancher_ui_uri,
  } end
end 


##########################
# DEFINITIONS (i.e. RCL) #
##########################
define launch_cluster(@rancher_server, @rancher_host, @ssh_key, @sec_group, @sec_group_rule_http8080, @sec_group_rule_http80, @sec_group_rule_http443, @sec_group_rule_ssh, @sec_group_rule_udp500, @sec_group_rule_udp4500, $map_cloud, $param_location, $map_st, $needsSshKey, $needsSecurityGroup)  return @rancher_server, @rancher_host, $rancher_ui_uri  do 
  
  # Need the cloud name later on
  $cloud_name = map( $map_cloud, $param_location, "cloud" )

  # Check if the selected cloud is supported in this account.
  # Since different PIB scenarios include different clouds, this check is needed.
  # It raises an error if not which stops execution at that point.
  call checkCloudSupport($cloud_name, $param_location)
  
  # Find and import the server template - just in case it hasn't been imported to the account already
  call importServerTemplate($map_st)
  
  # Provision the resources
  
  # Provision the SSH key if applicable.
  if $needsSshKey
    provision(@ssh_key)
  end
  
  # Provision the security group rules if applicable. (The security group itself is created when the server is provisioned.)
  if $needsSecurityGroup
    provision(@sec_group_rule_http8080)
    provision(@sec_group_rule_http80)
    provision(@sec_group_rule_http443)
    provision(@sec_group_rule_ssh)
    provision(@sec_group_rule_udp500)
    provision(@sec_group_rule_udp4500)
  end

  # Need to launch the rancher server first since the hosts need to know the URL for the server.
  # Plus some keys need to be generated on the server before the hosts can do their thing.
  # To-do: Play with concurrent launches and then subsequent script calls on the hosts to get things synched up.
  
  # Launch the server
  provision(@rancher_server)
  if @rancher_server.state != "operational"
    raise "Rancher Server did not successfully launch."
  end
  
  # Get the rancher server's IP address
  $rancher_server_ip = @rancher_server.current_instance().public_ip_addresses[0]
  $rancher_ui_uri = join(["http://", $rancher_server_ip, ":8080/"])
    
  # Call the rancher server API to generate the API keys needed by the hosts and extract them from the response.
  $response = http_post(
    url: join([$rancher_ui_uri, "v1/projects/1a5/apikeys"])
  )
  $body = $response["body"]
  $publicValue = $body["publicValue"] # Public API key
  $secretValue = $body["secretValue"] # Secret API key
    
  # Update the Rancher Server inputs (and deployment level for good measure) with the keys for future rancher-compose support.
  $inp = {
    'RANCHER_COMPOSE_ACCESS_KEY':join(["text:", $publicValue]),  # to-do: create a CREDENTIAL to store this value and use cred:
    'RANCHER_COMPOSE_SECRET_KEY':join(["text:", $secretValue]), # to-do: create a CREDENTIAL to store this value and use cred:
    'RANCHER_COMPOSE_URL':"text:http://localhost:8080/"
  } 
  @rancher_server.current_instance().multi_update_inputs(inputs: $inp) 
  @@deployment.multi_update_inputs(inputs: $inp) 

  # Update the Deployment level inputs with the rancher server related values.
  $inp = {
    'RANCHER_ACCESS_KEY':join(["text:", $publicValue]),  # to-do: create a CREDENTIAL to store this value and use cred:
    'RANCHER_SECRET_KEY':join(["text:", $secretValue]), # to-do: create a CREDENTIAL to store this value and use cred:
    'RANCHER_URL':join(["text:", $rancher_ui_uri])
  } 
  @@deployment.multi_update_inputs(inputs: $inp) 
  
  # Launch the rancher host array
  provision(@rancher_host)
 
end 

####################
# Helper Functions #
####################
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