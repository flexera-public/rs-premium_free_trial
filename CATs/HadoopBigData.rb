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
# Deploys a Hadoop cluster
# It automatically imports the ServerTemplate it needs.
# Also, it creates any other artifacts (e.g. ssh key) it needs.


# Required prolog
name 'E) Hadoop Big Data'
rs_ca_ver 20131202
short_description "![Hadoop Cluster](https://s3.amazonaws.com/rs-pft/cat-logos/hadoop.png)\n
Launch a Hadoop Cluster"
long_description "Launch a Hadoop cluster with a data node cluster of up to 4 servers.\n
\n
Clouds Supported: <B>AWS, Azure</B>"


parameter "param_location" do 
  category "Deployment Options"
  label "Cloud" 
  type "string" 
  allowed_values "AWS", "Azure"
  default "AWS"
end

parameter "param_instancetype" do
  category "Deployment Options"
  label "Server Performance Level"
  type "list"
  allowed_values "Standard Performance",
    "High Performance"
  default "Standard Performance"
end

parameter 'param_qty' do
  category "Hadoop Configuration Options"
  type 'number'
  label 'Number of Data Nodes in the Cluster'
  description 'Enter a value from 1 to 4.'
  min_value 1
  max_value 4
  default 1
end

################################
# Outputs returned to the user #
################################

output 'hadoop_namenode_portal' do
  label "HDFS Portal" 
  category "Connect"
  default_value $namenode_portal
  description "Service public IPs"
end

output 'hadoop_data_portal' do
  label "Job Portal" 
  category "Connect"
  default_value $data_portal
  description "Service public IPs"
end

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
    "cloud" => "VMware Private Cloud",
    "zone" => "VMware_Zone_1", # launches in vSphere require a zone being specified  
    "instance_type" => "large",
    "sg" => null, 
    "ssh_key" => "@ssh_key",
    "pg" => null,
    "mci_mapping" => "VMware",
  }
}
end

mapping "map_instancetype" do {
  "Standard Performance" => {
    "AWS" => "m3.medium",
    "Azure" => "medium",
    "Google" => "n1-standard-1",
    "VMware" => "medium",
  },
  "High Performance" => {
    "AWS" => "m3.large",
    "Azure" => "large",
    "Google" => "n1-standard-2",
    "VMware" => "large",
  }
} end

mapping "map_st" do {
  "hadoop_server" => {
    "name" => "Apache Hadoop (v13.1)",
    "rev" => "9",
  },
} end

mapping "map_mci" do {
  "Ubuntu" => {
    "mci" => "RightImage_Ubuntu_12.04_x64_v5.8",
    "mci_rev" => "11"
  },
  "CentOS" => {
    "mci" => "RightImage_CentOS_6.3_x64_v5.8",
    "mci_rev" => "13"
  },
} end

mapping "hadoop_config" do {
  "ports" => {
    "datanode_address" => "50010",
    "datanode_http" => "50075",
    "datanode_ipc" => "50020",
    "namenode_address" => "8020",
    "namenode_http" => "50070",
  },
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

### Server Declarations ###
resource 'namenode', type: 'server' do
  name 'NameNode - Hadoop'
  cloud map($map_cloud, $param_location, "cloud")
  datacenter map($map_cloud, $param_location, "zone")
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  security_group_hrefs map($map_cloud, $param_location, "sg")  
  placement_group_href map($map_cloud, $param_location, "pg")
  server_template_href find(map($map_st, "hadoop_server", "name"), revision: map($map_st, "hadoop_server", "rev"))
  multi_cloud_image find(map($map_mci, "Ubuntu", "mci"), revision: map($map_mci, "Ubuntu", "mci_rev")) # Only using Ubuntu
  instance_type map($map_instancetype, $param_instancetype, $param_location)
  inputs do {
       'hadoop/node/type' => 'text:namenode'
  } end
end

resource 'datanode_cluster', type: 'server_array' do
  name 'DataNode Cluster - Hadoop'
  cloud map($map_cloud, $param_location, "cloud")
  datacenter map($map_cloud, $param_location, "zone")
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  security_group_hrefs map($map_cloud, $param_location, "sg")  
  placement_group_href map($map_cloud, $param_location, "pg")
  server_template_href find(map($map_st, "hadoop_server", "name"), revision: map($map_st, "hadoop_server", "rev"))
  multi_cloud_image find(map($map_mci, "Ubuntu", "mci"), revision: map($map_mci, "Ubuntu", "mci_rev")) # Only using Ubuntu
  instance_type map($map_instancetype, $param_instancetype, $param_location)
  inputs do {
       'hadoop/node/type' => 'text:datanode'
  } end
  # Array is used to build a cluster of data nodes. No scaling is supported at this time.
  state 'disabled'
  array_type 'alert'
  elasticity_params do {
    'bounds' => {
      'min_count' => $param_qty,
      'max_count' => $param_qty
    },
    'pacing' => {
      'resize_calm_time' => 10,
      'resize_down_by' => 1,
      'resize_up_by' => 1
    },
    'alert_specific_params' => {
      'decision_threshold' => 51,
      'voters_tag_predicate' => 'notdefined'
    }
  } end
end  

### Security Group Declarations ###
# Note: Even though not all environments need or use security groups, the launch operation/definition will decide whether or not
# to provision the security group and rules.
resource "sec_group", type: "security_group" do
#  condition $needsSecurityGroup

  name join(["hadoopbigdata-",@@deployment.href])
  description "Hadoop cluster security group."
  cloud map( $map_cloud, $param_location, "cloud" )
end

resource "sgrule_ssh", type: "security_group_rule" do
#  condition $needsSecurityGroup

  name "SSH Rule"
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

resource "sgrule_datanode_address", type: "security_group_rule" do
#  condition $needsSecurityGroup

  name "DataNode Address Rule"
  source_type "cidr_ips"
  security_group @sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => map( $hadoop_config, "ports", "datanode_address"),
    "end_port" => map( $hadoop_config, "ports", "datanode_address")
  } end
end

resource "sgrule_datanode_http", type: "security_group_rule" do
#  condition $needsSecurityGroup

  name "DataNode HTTP Rule"
  source_type "cidr_ips"
  security_group @sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => map( $hadoop_config, "ports", "datanode_http"),
    "end_port" => map( $hadoop_config, "ports", "datanode_http")
  } end
end

resource "sgrule_datanode_ipc", type: "security_group_rule" do
#  condition $needsSecurityGroup

  name "DataNode IPC Rule"
  source_type "cidr_ips"
  security_group @sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => map( $hadoop_config, "ports", "datanode_ipc"),
    "end_port" => map( $hadoop_config, "ports", "datanode_ipc")
  } end
end

resource "sgrule_namenode_address", type: "security_group_rule" do
#  condition $needsSecurityGroup

  name "NameNode Address Rule"
  source_type "cidr_ips"
  security_group @sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => map( $hadoop_config, "ports", "namenode_address"),
    "end_port" => map( $hadoop_config, "ports", "namenode_address")
  } end
end

resource "sgrule_namenode_http", type: "security_group_rule" do
#  condition $needsSecurityGroup

  name "NameNode HTTP Rule"
  source_type "cidr_ips"
  security_group @sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => map( $hadoop_config, "ports", "namenode_http"),
    "end_port" => map( $hadoop_config, "ports", "namenode_http")
  } end
end
### END OF SECURITY GROUP DECLARATIONS ###

### SSH Key ###
resource "ssh_key", type: "ssh_key" do
#  condition $needsSshKey

  name join(["sshkey_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
end

### Placement Group ###
resource "placement_group", type: "placement_group" do
#  condition $needsPlacementGroup

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


####################
# OPERATIONS       #
####################

operation 'launch' do 
  description 'Launch the application' 
  definition 'launch_servers' 
  output_mappings do {
    $hadoop_namenode_portal => $namenode_portal,
    $hadoop_data_portal => $data_portal,
  } end
end 

# Import and set up what is needed for the server and then launch it.
# This does NOT install WordPress.
define launch_servers(@namenode, @datanode_cluster, @sec_group, @sgrule_ssh, @sgrule_datanode_address, @sgrule_datanode_http, @sgrule_datanode_ipc, @sgrule_namenode_address, @sgrule_namenode_http, @ssh_key, @placement_group, $hadoop_config, $map_cloud, $map_st, $param_location, $needsSshKey, $needsSecurityGroup, $needsPlacementGroup, $inAzure) return @namenode, @datanode_cluster, @sec_group, @ssh_key, $namenode_portal, $data_portal do
  
  # Need the cloud name later on
  $cloud_name = map( $map_cloud, $param_location, "cloud" )

  # Check if the selected cloud is supported in this account.
  # Since different PIB scenarios include different clouds, this check is needed.
  # It raises an error if not which stops execution at that point.
  call checkCloudSupport($cloud_name, $param_location)
  
  # Find and import the server template - just in case it hasn't been imported to the account already
  call importServerTemplate($map_st)
     
  # Create the Hadoop SSH bits if needed
  call manageHadoopSshKeys()
    
  # Provision all the needed resources
  
  # Provision the SSH key if applicable.
  if $needsSshKey
    provision(@ssh_key)
  end

  # Provision the security group rules if applicable. (The security group itself is created when the server is provisioned.)
  if $needsSecurityGroup
    provision(@sgrule_ssh)
    provision(@sgrule_datanode_address)
    provision(@sgrule_datanode_http)
    provision(@sgrule_datanode_ipc)
    provision(@sgrule_namenode_address)
    provision(@sgrule_namenode_http)
  end
  
  # Provision the placement group if applicable
  if $needsPlacementGroup
    provision(@placement_group)
  end
  
  # Set the deployment level inputs
  $inp = {
    'hadoop/datanode/address/port':join(["text:", map( $hadoop_config, "ports", "datanode_address")]),
    'hadoop/datanode/http/port':join(["text:", map( $hadoop_config, "ports", "datanode_http")]),
    'hadoop/datanode/ipc/port':join(["text:", map( $hadoop_config, "ports", "datanode_ipc")]),
    'hadoop/namendoe/address/port':join(["text:", map( $hadoop_config, "ports", "namenode_address")]),
    'hadoop/namenode/http/port':join(["text:", map( $hadoop_config, "ports", "namenode_http")]),
    'hadoop/dfs/replication':'text:3',
    'rightscale/private_ssh_key':'cred:HADOOP_PRIVATE_SSH_KEY',
    'rightscale/public_ssh_key':'cred:HADOOP_PUBLIC_SSH_KEY',
    'repo/default/repository':'text:not_needed',
    'sys_firewall/enabled':'text:disabled'
  }
  @@deployment.multi_update_inputs(inputs: $inp)
  
  # Provision the servers
  concurrent return @namenode, @datanode_cluster do
    sub task_name:"Launch NameNode" do
      task_label("Launching NameNode")
      $namenode_retries = 0 
      sub on_error: handle_retries($namenode_retries) do
        $namenode_retries = $namenode_retries + 1
        provision(@namenode)
      end
    end
    
    sub task_name:"Launch DataNode Cluster" do
      task_label("Launching DataNode Cluster")
      $datanode_retries = 0 
      sub on_error: handle_retries($datanode_retries) do
        $datanode_retries = $datanode_retries + 1
        provision(@datanode_cluster)
      end
    end
  end
  
  # Now we re-run the attach script so the namenode will find the datanode.
  # This is done in case the datanode actually came up before the namenode due to the concurrency used above.
  call run_recipe_inputs(@namenode, "hadoop::handle_attach", {})  

  # If deployed in Azure one needs to set up the port mapping that Azure uses.
  if $inAzure
    
    # Find the current bindings for the namenode instance and then drill down to find the IP address href
    @bindings = rs.clouds.get(href: @namenode.current_instance().cloud().href).ip_address_bindings(filter: ["instance_href==" + @namenode.current_instance().href])
    @binding = select(@bindings, {"private_port":22})
    @ipaddr = @binding.ip_address()
    
    # Create the bindings. We are just using the same port for public and private and quite honestly hoping they haven't already been used for public. What are the odds ...?
    @namenode.current_instance().cloud().ip_address_bindings().create({"instance_href" : @namenode.current_instance().href, 
      "public_ip_address_href" : @ipaddr.href, 
      "protocol" : "TCP", 
      "private_port" : map( $hadoop_config, "ports", "namenode_http"), 
      "public_port" : map( $hadoop_config, "ports", "namenode_http")})
      
    @namenode.current_instance().cloud().ip_address_bindings().create({"instance_href" : @namenode.current_instance().href, 
      "public_ip_address_href" : @ipaddr.href, 
      "protocol" : "TCP", 
      "private_port" : map( $hadoop_config, "ports", "datanode_http"), 
      "public_port" : map( $hadoop_config, "ports", "datanode_http")})
    
  end
  
  # return the output values which are, in this case, the same regardless of which cloud.
  $namenode_portal = join(["http://", to_s(@namenode.current_instance().public_ip_addresses[0]), ":", map( $hadoop_config, "ports", "namenode_http")])
  $data_portal = join(["http://", to_s(@namenode.current_instance().public_ip_addresses[0]), ":", map( $hadoop_config, "ports", "datanode_http")])
 
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

# Creates if needed a couple of credentials used by the Hadoop nodes to communicate.
define manageHadoopSshKeys() do
  
  # Temporary as ways to automatically generate these items is investigated
  $key_hash = { 
    "HADOOP_PUBLIC_SSH_KEY" => "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDjaEXsYfJ5I4QkQglQNFYmzpIoG8oqhSATf4FN4HtQd6K9TLLnbBFYIbXbtwVjRQI3b8+9AABhY0PovV06KJl79fB8ynrb5SJBKi8cPqhAj96122overn/3PLFiSLhcbP2XDXdT/VkDysCJelOnPVoHxXyUNRwoI2ZasvFLJgjjMVmKvbdfpTKeBzfL8+PYi5WP3+2o27lj6vAJnAP1yl4HB7Yiln6rF0JBJoC0WLnXZSsWYd9kByRV93K9p5XaZ3am8Z8f629QwdIiAJGrGMuqpjzJMqvgchQxKm1B2cdcd6Hunz4XlGFO0+vAjGxFmEyVu6SLZOxT1vckSpDc1PN rightscale@ip-10-34-211-202",
    "HADOOP_PRIVATE_SSH_KEY" => "-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA42hF7GHyeSOEJEIJUDRWJs6SKBvKKoUgE3+BTeB7UHeivUyy
52wRWCG127cFY0UCN2/PvQAAYWND6L1dOiiZe/XwfMp62+UiQSovHD6oQI/etdtq
L3q5/9zyxYki4XGz9lw13U/1ZA8rAiXpTpz1aB8V8lDUcKCNmWrLxSyYI4zFZir2
3X6Uyngc3y/Pj2IuVj9/tqNu5Y+rwCZwD9cpeBwe2IpZ+qxdCQSaAtFi512UrFmH
fZAckVfdyvaeV2md2pvGfH+tvUMHSIgCRqxjLqqY8yTKr4HIUMSptQdnHXHeh7p8
+F5RhTtPrwIxsRZhMlbuki2TsU9b3JEqQ3NTzQIDAQABAoIBACvzKSBoRa532MAR
Ky+fDc9uOP0bcdUJ6YsbJ2hfrDV/CarAOgtT7X409arDEn1/BtCkAWgrqecogiVn
A6+LzS4R+CqGD3yUKiyh9Hzm9ymTJJ3NDBalB3GVyC25NU6Q5REF/TsKiwiNjeha
X17cIum+qEUurgAeZ39xDnTLC5RC8TBHoYEdpauOehsnEjunNyi6SfTmyF5dqu2v
yA7S5Og+sc4rnWYLRR8owoEZMnYyncRyQk7EY/OIZc/S0YdsIN/iJOnTsVlRh+E7
1IPH6ZKbm1qSI+LN6bPoL92aAzgTDEGUrPsngQUZIhb2NoVpoBG0fcKnIBPpYeUF
Tv2bt8ECgYEA/6XM7EEGzD23Nc47FszRJvpV2YI7Rh/6djN871np6jrX2SwuTcDv
+SErBZl7ZwWaX4G2PsbMkO7HGEkRqOiBBUk3VtOCnjGFp+9QEgD+QwXpZiK1R9+X
RiFc7JEXfZBdaaGa93AGWTrmJTc8DnS/LL9z1+beCwbqFBgHADh7SbUCgYEA47iC
OXysCOESxDBCltSQ5Bx1nvHlUv2mKScQdz1I5E34MdkzWa7owFhE6PrI1cZqJ/eV
M5eft0sp3gowR7re425yNFHIkVMCG6omzeFCp0iLO/yWgpdJiH6tZH8iYl/M8PxB
lkVu95dLmh1hsk0ITy6Z2kD61SAUEveHiVeY0LkCgYAjkU/HduyZMeTxiXXTID/h
KmcTUfkpMn3IQDWbn2jZ+8HYJztx+evpP2Ia71Wp6a+mpgdTCJmheHceu9vHIkIB
GESowdikZcNwr+z19ElrzcDBQwbxrvv+99lT2IPqJlG4xpEm5+EaPQWUG/ExGbEX
arOVUDuIUTfz/7vJnhIZGQKBgQCTPzZth7ESGL9yvqYAM7jw13oy6cVYcY1k5M6f
26/reIM5cHHk1tXHsgv0/lyo5qCz8UK31p4+/ko3Oi1X5HzFYSBVtmBTn/IoA1EO
JU9dLepiQoTsMnko2oiyCAcqxzmUxfh++6yySlFneQI4MdliogZ3+zZ2Y0S3svkg
FNVKeQKBgQCGnicjc4lVjgZ4Nsm6s1shIpTeHH2vAlm+nAOnurEsSm/iYG2crp6N
qbMmVkwz1eQXKICM5lIhzyB8dNcSo1zWBvlnUu8ZIXgBZCtUPo4/oD0KQa2YGuBW
YavRrlAL/ZA0AwVCbgC1buHaJmP+fGmw+hNthmvVgSiMnG3nV+tIfg==
-----END RSA PRIVATE KEY-----"
  }
  
 foreach $name in keys($key_hash) do
   @cred = rs.credentials.get(filter: join(["name==",$name]))
   if empty?(@cred)  # need to create the cred to store the info
     @task=rs.credentials.create({"name":$name, "value": $key_hash[$name]})
   end
 end

end

# Helper functions
define handle_retries($attempts) do
  if $attempts < 3
    $_error_behavior = "retry"
    sleep(60)
  else
    $_error_behavior = "skip"
  end
end

define run_recipe_inputs(@target, $recipe_name, $recipe_inputs) do
  @task = @target.current_instance().run_executable(recipe_name: $recipe_name, inputs: $recipe_inputs)
  sleep_until(@task.summary =~ "^(completed|failed)")
  if @task.summary =~ "failed"
    raise "Failed to run " + $recipe_name
  end
end

