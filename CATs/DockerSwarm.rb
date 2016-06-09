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
# Deploys a Docker Swarm cluster.
# It deploys at least one node that acts as the swarm manager and the first swarm node.
# The user can specify the number of nodes to launch as well.
#
# TO-DO:
# - Support scaling out additional nodes after launch.
# - Add some predefined application stacks to launch.


# Required prolog
name 'Docker Swarm'
rs_ca_ver 20160108
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/dockerswarm.png) 

Launches a Docker Swarm cluster."
long_description "Launch a Docker Swarm cluster.\n
\n
Clouds Supported: <B>AWS, Google</B>"

##################
# Imports        #
##################

import "util/server_templates"
import "util/err"
import "util/cloud"
import "common/mappings", as: 'common_mappings'

##################
# Permissions    #
##################
permission "import_servertemplates" do
  actions   "rs_cm.import"
  resources "rs_cm.publications"
end

##################
# User inputs    #
##################
parameter "param_location" do
  category "User Inputs"
  label "Cloud"
  type "string"
  description "Cloud to deploy in."
  allowed_values "AWS" # Only AWS is currently supported at this time.
  default "AWS"
end

parameter "param_num_nodes" do
  type "string"
  label "Number of Node Servers"
  category "User Inputs"
  default "1"
  allowed_pattern "^([1-4])$"
  constraint_description "Must be a value between 1-4"
end

parameter "param_costcenter" do 
  category "User Inputs"
  label "Cost Center" 
  type "string" 
  allowed_values "Development", "QA", "Production"
  default "Development"
end

parameter "num_add_nodes" do
  category "Swarm Options"
  type "number"
  label "Number of Swarm Nodes to Add to the Cluster"
  description "Enter the number of hosts you want to add to the swarm."
  default 1
end

################################
# Outputs returned to the user #
################################
output "manager_ssh_link" do
  label "Swarm Manager SSH Link"
  category "Access"
  description "Use this string along with your SSH key to access your server."
  default_value join(["ssh://rightscale@", @swarm_manager.public_ip_address])
end

output "ssh_key_info" do
  label "Link to your SSH Key"
  category "Access"
  description "Use this link to download your SSH private key and use it to login to the server using provided \"SSH Link\"."
  default_value "https://my.rightscale.com/global/users/ssh#ssh"
end

[*0..10].each do |n|
  output "node_#{n}_id" do
    label "Docker Node #{n}"
    category "Docker Nodes"
    description "The ID of the node server.\n NOTE: Node 0 is also the manager node."
  end
end

##############
# MAPPINGS   #
##############
mapping "map_cloud" do
  like $common_mappings.map_cloud
end

mapping "map_st" do {
  "swarm_manager" => {
    "name" => "Docker Swarm Manager",
    "rev" => "4",
  },
  "swarm_node" => {
    "name" => "Docker Swarm Node",
    "rev" => "4",
  },
} end

mapping "map_mci" do {
  "VMware" => { # vSphere not currently supported by this CAT
    "mci_name" => "NA",
    "mci_rev" => "NA",
  },
  "Public" => { # all other clouds
    "mci_name" => "Ubuntu_14.04_x64",
    "mci_rev" => "10",
  }
} end

##################
# CONDITIONS     #
##################

condition "needsSshKey" do
  logic_or(equals?($param_location, "AWS"), equals?($param_location, "VMware"))
end

condition "needsSecurityGroup" do
  logic_or(equals?($param_location, "AWS"), equals?($param_location, "Google"))
end

condition "invSphere" do
  equals?($param_location, "VMware")
end

condition "inAzure" do
  equals?($param_location, "Azure")
end

condition "needsPlacementGroup" do
  equals?($param_location, "Azure")
end 

############################
# RESOURCE DEFINITIONS     #
############################

### Server Definitions ###

# Docker Swarm Manager Server
resource "swarm_manager", type: "server" do
  name "Docker Swarm Manager"
  cloud map($map_cloud, $param_location, "cloud")
  datacenter map($map_cloud, $param_location, "zone")
  instance_type map($map_cloud, $param_location, "instance_type")
  server_template_href find(map($map_st, "swarm_manager", "name"), revision: map($map_st, "swarm_manager", "rev"))
  multi_cloud_image_href find(map($map_mci, "Public", "mci_name"), revision: map($map_mci, "Public", "mci_rev"))
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  placement_group_href map($map_cloud, $param_location, "pg")
  security_group_hrefs map($map_cloud, $param_location, "sg")  
  inputs do {
    "SWARM_CLUSTER_ID"  => join(["text:swarm_", last(split(@@deployment.href,"/"))])
  } end
end

# Docker Swarm Node Server Array
resource "swarm_node", type: "server_array" do
  name "Docker Swarm Node Array"
  cloud map($map_cloud, $param_location, "cloud")
  datacenter map($map_cloud, $param_location, "zone")
  instance_type map($map_cloud, $param_location, "instance_type")
  server_template_href find(map($map_st, "swarm_node", "name"), revision: map($map_st, "swarm_node", "rev"))
  multi_cloud_image_href find(map($map_mci, "Public", "mci_name"), revision: map($map_mci, "Public", "mci_rev"))
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  placement_group_href map($map_cloud, $param_location, "pg")
  security_group_hrefs map($map_cloud, $param_location, "sg") 
  inputs do {
    "SWARM_CLUSTER_ID"  => join(["text:swarm_", last(split(@@deployment.href,"/"))])
  } end
  state "enabled"
  array_type "alert"
  elasticity_params do {
    "bounds" => {
      "min_count"            => $param_num_nodes,
      "max_count"            => 10
    },
    "pacing" => {
      "resize_calm_time"     => 5,
      "resize_down_by"       => 1,
      "resize_up_by"         => 1
    },
    "alert_specific_params" => {
      "decision_threshold"   => 51,
      "voters_tag_predicate" => "Swarm Node Tier"
    }
  } end
end

### Security Group Definitions ###
# Note: Even though not all environments need or use security groups, the launch operation/definition will decide whether or not
# to provision the security group and rules.

resource "sec_group", type: "security_group" do
  name join(["DockerSwarm-",@@deployment.href])
  description "Docker Swarm application security group."
  cloud map( $map_cloud, $param_location, "cloud" )
end

resource "sec_group_rule_ssh", type: "security_group_rule" do
  name "DockerSwarm server SSH Rule"
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

resource "sec_group_rule_swarmnode", type: "security_group_rule" do
  name "DockerSwarm node access Rule"
  description "Allow manager to access node."
  source_type "cidr_ips"
  security_group @sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "2376",
    "end_port" => "2376"
  } end
end

### SSH Key ###
resource "ssh_key", type: "ssh_key" do
  name join(["sshkey_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
end

####################
# OPERATIONS       #
####################
operation "launch" do 
  description "Launch the application"
  definition "launch"

  hash = {}
  [*0..10].each do |n|
    hash[eval("$node_#{n}_id")] = switch(get(n,$swarm_node_ids),  get(0,get(n,$swarm_node_ids)), "")
  end
  
  output_mappings do 
    hash
  end
 
end

operation "add_nodes_to_swarm" do
  label "Add Nodes to Swarm"
  description "Adds (scales out) nodes to the Swarm."
  definition "add_nodes"
  hash = {}
  [*0..10].each do |n|
    hash[eval("$node_#{n}_id")] = switch(get(n,$swarm_node_ids),  get(0,get(n,$swarm_node_ids)), "")
  end
  
  output_mappings do 
    hash
  end
end


##########################
# DEFINITIONS (i.e. RCL) #
##########################
# Import and set up what is needed for the server and then launch it.
define launch(@swarm_manager, @swarm_node, @ssh_key, @sec_group, @sec_group_rule_ssh, @sec_group_rule_swarmnode, $map_cloud, $map_st, $param_location, $param_costcenter, $needsSshKey, $needsSecurityGroup) return @swarm_manager, @swarm_node, @sec_group, @ssh_key, $swarm_node_ids do

  # Need the cloud name later on
  $cloud_name = map( $map_cloud, $param_location, "cloud" )

  # Check if the selected cloud is supported in this account.
  # Since different PIB scenarios include different clouds, this check is needed.
  # It raises an error if not which stops execution at that point.
  call cloud.checkCloudSupport($cloud_name, $param_location)
  
  # Find and import the server template - just in case it hasn't been imported to the account already
  call server_templates.importServerTemplate($map_st)
    
  # Provision all the needed resources
  
  # Provision the SSH key if applicable.
  if $needsSshKey
    provision(@ssh_key)
  end

  # Provision the security group rules if applicable. (The security group itself is created when the server is provisioned.)
  if $needsSecurityGroup
    provision(@sec_group_rule_ssh)
    provision(@sec_group_rule_swarmnode)
  end
  
  # Provision the servers
  concurrent return @swarm_manager, @swarm_node do
    sub task_name:"Launch Swarm Manager" do
      task_label("Launching Swarm Manager")
      $swarm_manager_retries = 0 
      sub on_error: err.handle_retries($swarm_manager_retries) do
        $swarm_manager_retries = $swarm_manager_retries + 1
        provision(@swarm_manager)
      end
    end
    
    sub task_name:"Launch Swarm Node Cluster" do
      task_label("Launching Swarm Node Cluster")
      $swarm_node_retries = 0 
      sub on_error: err.handle_retries($swarm_node_retries) do
        $swarm_node_retries = $swarm_node_retries + 1
        provision(@swarm_node)
      end
    end
  end
  
  # Now we re-run the manager script so the swarm manager will discover the swarm nodes.
  call server_template.run_script("APP docker swarm manage", @swarm_manager)
  
  # Now tag the servers with the selected project cost center ID.
  $tags=[join(["costcenter:id=",$param_costcenter])]
  rs_cm.tags.multi_add(resource_hrefs: @@deployment.servers().current_instance().href[], tags: $tags)
  rs_cm.tags.multi_add(resource_hrefs: @@deployment.server_arrays().current_instances().href[], tags: $tags)

  # Get the array of node instances IDs from the server array.
  @instances= rs_cm.get(href: @@deployment.href).server_arrays().current_instances()
  
  # Get a list of node IDs as they appear when listing nodes or containers in docker.
  # In AWS this is basically the host name which is the first part of the private DNS name.
  $swarm_node_ids = []  # This is an array of single-element arrays since that's what the output mapping code expects.
  # Seed it with the manager ID since it's a node and a manager in one!
  $swarm_node_ids << [ split(@swarm_manager.current_instance().private_dns_names[0], ".")[0] ]   
  # Get the other node IDs in the list
  foreach @instance in @swarm_node.current_instances() do
    $swarm_node_ids << [ split(@instance.private_dns_names[0], ".")[0] ]
  end

end 

# Add nodes to the cluster
define add_nodes(@swarm_node, @swarm_manager, $num_add_nodes) return $swarm_node_ids do
  @task = @swarm_node.launch(count:$num_add_nodes)  
  
  sleep(90) # Give the servers a chance to get started before checking for states and problems
  
  $wake_condition = "/^(operational|stranded|stranded in booting|stopped|terminated|inactive|error)$/"
  sleep_until all?(@swarm_node.current_instances().state[], $wake_condition)
  
  rs_cm.audit_entries.create(auditee_href: @@deployment, summary: "instance states after waking", detail: to_s(@swarm_node.current_instances().state[]))

  if !all?(@swarm_node.current_instances().state[], "operational")
    raise "Some instances failed to start"    
  end
  
  # Get a list of node IDs as they appear when listing nodes or containers in docker.
  # In AWS this is basically the host name which is the first part of the private DNS name.
  $swarm_node_ids = []  # This is an array of single-element arrays since that's what the output mapping code expects.
  # Seed it with the manager ID since it's a node and a manager in one!
  $swarm_node_ids << [ split(@swarm_manager.current_instance().private_dns_names[0], ".")[0] ]   
  # Get the other node IDs in the list
  foreach @instance in @swarm_node.current_instances() do
    $swarm_node_ids << [ split(@instance.private_dns_names[0], ".")[0] ]
  end
end
