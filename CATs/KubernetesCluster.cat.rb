name 'Kubernetes Cluster'
rs_ca_ver 20161221
short_description "![logo](https://dl.dropboxusercontent.com/u/2202802/nav_logo.png)

Creates a Kubernetes cluster"

long_description "### Description

#### Kubernetes

Kubernetes is an open source cluster manager, a software package that manages a cluster of servers as a scalable pool of resources for deploying Docker containers.

#### This CloudApp

RightScale's Self-Service integration for Kubernetes makes it easy to launch and scale a dynamically-sized cluster, manage access, and deploy workloads across the pool of servers.

---

### Parameters

#### Minimum Node Count

Enter the minimum number of nodes for the cluster. Autoscaling will maintain node count between minimum and maximum.

#### Maximum Node Count

Enter the maximum number of nodes for the cluster. Autoscaling will maintain node count between minimum and maximum.

#### Cloud

Choose a target cloud for this cluster.

#### Admin IP

Enter your public IP address as visible to the public Internet. This will be used to create a rule in the cluster's security group to allow you full access to the cluster for administration. You can visit [http://ip4.me](http://ip4.me) to verify your public IP.

---

### Outputs

#### Launch Kubernetes dashboard

Click this link to launch the Kubernetes dashboard. Documentation for using this dashboard to deploy and manage applications can be found at [http://kubernetes.io/docs/user-guide/ui](http://kubernetes.io/docs/user-guide/ui).

#### View Hello app

Click this link to view the Hello World web app that has been deployed to the cluster.

#### Master server IP

This output displays the IP of the master server. Use your usual SSH connection method to initiate a SSH session on the master server.

#### Authorized admin IPs

Contains a list of IP addresses that have been authorized for full administrative access to the cluster.

---

### Actions

#### Add Admin IP

This action can be used to authorize an additional IP for full administrative access to the cluster.

#### Update Autoscaling Range

This action will modify the minimum and maximum number of cluster nodes. Although the action completes right away, please wait up to 30 minutes for the requested changes to happen in the background, especially when new servers are being launched.

#### Install Hello app

This action will install a basic Hello World web app onto the cluster.

---"

import "pft/mappings"
import "pft/permissions"
import "pft/account_utilities", as: "rs_acct"
import "pft/server_templates_utilities", as: "rs_st"

##################
# Permissions    #
##################
permission "pft_general_permissions" do
  like $permissions.pft_general_permissions
end

permission "pft_sensitive_views" do
  like $permissions.pft_sensitive_views
end

##################
# User inputs    #
##################

parameter "node_count_min" do
  type "number"
  label "Minimum Node Count"
  category "Application"
  description "Minimum number of cluster nodes."
  min_value 1
  max_value 30
  default 3
end

parameter "node_count_max" do
  type "number"
  label "Maximum Node Count"
  category "Application"
  description "Maximum number of cluster nodes."
  min_value 1
  max_value 30
  default 6
end

parameter "cloud" do
  type "string"
  label "Cloud"
  category "Application"
  description "Target cloud for this cluster."
  allowed_values "AWS", "VMware"
  default "AWS"
end

parameter "admin_ip" do
  type "string"
  label "Admin IP"
  category "Application"
  description "Allowed source IP for cluster administration. This IP address will have full access to the cluster."
  allowed_pattern "^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$"
  constraint_description "Please enter a single IP address. Additional IPs can be added after launch."
end

################################
# Outputs returned to the user #
################################

output "master_ip" do
  label "Master server IP"
  category "Kubernetes"
end

output "dashboard_url" do
  label "Launch Kubernetes dashboard"
  category "Kubernetes"
end

output "admin_ips" do
  label "Authorized admin IPs"
  category "Kubernetes"
end

output "hello_url" do
  label "View Hello app"
  category "Kubernetes"
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

mapping "map_account" do {
  "AWS" => {
    "id" => "168969478693" },
  "VMware" => {
    "id" => null } }
end

############################
# RESOURCE DEFINITIONS     #
############################

resource 'cluster_sg', type: 'security_group' do
  name join(['cluster_sg_', last(split(@@deployment.href, '/'))])
  cloud map($map_cloud, $cloud, "cloud")
end

resource 'cluster_sg_rule_int_tcp', type: 'security_group_rule' do
  protocol 'tcp'
  direction 'ingress'
  source_type 'group'
  security_group @cluster_sg
  group_owner map($map_account, $cloud, "id")
  protocol_details do {
    'start_port' => '0',
    'end_port' => '65535'
  } end
end

resource 'cluster_sg_rule_int_udp', type: 'security_group_rule' do
  protocol 'udp'
  direction 'ingress'
  source_type 'group'
  security_group @cluster_sg
  group_owner map($map_account, $cloud, "id")
  protocol_details do {
    'start_port' => '0',
    'end_port' => '65535'
  } end
end

resource 'cluster_sg_rule_admin', type: 'security_group_rule' do
  protocol 'tcp'
  direction 'ingress'
  source_type 'cidr_ips'
  security_group @cluster_sg
  cidr_ips join([$admin_ip, '/32'])
  protocol_details do {
    'start_port' => '0',
    'end_port' => '65535'
  } end
end

resource 'cluster_master', type: 'server_array' do
  name 'cluster-master'
  cloud map($map_cloud, $cloud, "cloud")
  datacenter map($map_cloud, $cloud, "zone")
  instance_type map($map_instancetype, "High Performance", $cloud)
  server_template find('Kubernetes', revision: 0)
  inputs do {
    'RS_CLUSTER_ROLE' => 'text:master'
  } end
  state 'disabled'
  array_type 'alert'
  elasticity_params do {
    'bounds' => {
      'min_count'            => 1,
      'max_count'            => 1
    },
    'pacing' => {
      'resize_calm_time'     => 15,
      'resize_down_by'       => 1,
      'resize_up_by'         => 1
    },
    'alert_specific_params' => {
      'decision_threshold'   => 0,
      'voters_tag_predicate' => 'cluster_master'
    }
  } end
end

resource 'cluster_node', type: 'server_array' do
  name 'cluster-node'
  cloud map($map_cloud, $cloud, "cloud")
  datacenter map($map_cloud, $cloud, "zone")
  instance_type map($map_instancetype, "High Performance", $cloud)
  server_template find('Kubernetes', revision: 0)
  inputs do {
    'RS_CLUSTER_ROLE' => 'text:node'
  } end
  state 'disabled'
  array_type 'alert'
  elasticity_params do {
    'bounds' => {
      'min_count'            => $node_count_min,
      'max_count'            => $node_count_max
    },
    'pacing' => {
      'resize_calm_time'     => 15,
      'resize_down_by'       => 1,
      'resize_up_by'         => 3
    },
    'alert_specific_params' => {
      'decision_threshold'   => 0,
      'voters_tag_predicate' => 'cluster_node'
    }
  } end
end

####################
# OPERATIONS       #
####################

operation 'launch' do
  description 'Launch the application'
  definition 'launch'
  output_mappings do {
    $master_ip => $new_master_ip,
    $admin_ips => $new_admin_ips,
    $dashboard_url => join(["http://", $new_master_ip, ":8001/ui"])
  } end
end

operation 'terminate' do
  description 'Terminate the application'
  definition 'terminate'
end

operation 'op_add_admin_ip' do
  label 'Add Admin IP'
  description 'Authorize an additional admin IP for full access to the cluster'
  definition 'add_admin_ip'
  output_mappings do {
    $admin_ips => $new_admin_ips
  } end
end

operation 'op_update_autoscaling_range' do
  label 'Update Autoscaling Range'
  description 'Modify the minimum and maximum number of nodes'
  definition 'resize_cluster'
end

operation 'op_install_hello_app' do
  label 'Install Hello app'
  description 'Install a basic Hello World web app onto the cluster'
  definition 'install_hello'
  output_mappings do {
    $hello_url => join(["http://", $node_ip, ":", $hello_port])
  } end
end

##########################
# DEFINITIONS (i.e. RCL) #
##########################

define launch(@cluster_master, @cluster_node, @cluster_sg, @cluster_sg_rule_admin, @cluster_sg_rule_int_tcp, @cluster_sg_rule_int_udp, $admin_ip, $cloud) return @cluster_master, @cluster_node, @cluster_sg, @cluster_sg_rule_admin, @cluster_sg_rule_int_tcp, @cluster_sg_rule_int_udp, $new_master_ip, $new_admin_ips do

  task_label("Setting cluster parameters")

  call kube_get_execution_id() retrieve $execution_id
  call rs_acct.find_shard() retrieve $shard_number

  $shard_hostname = 'us-' + $shard_number + '.rightscale.com'

  @@deployment.multi_update_inputs(inputs: {
    'RS_SHARD_HOSTNAME': 'text:' + $shard_hostname,
    'RS_CLUSTER_NAME': 'text:' + $execution_id,
    'RS_CLUSTER_CLOUD': 'text:' + $cloud,
    'RS_CLUSTER_TYPE': 'text:kubernetes'
  })

  if $cloud == "AWS"
    task_label("Provisioning security groups")

    provision(@cluster_sg)

    call security_group_name($cloud, @cluster_sg) retrieve $security_group_name
    call update_field(@cluster_sg_rule_int_tcp, "group_name", $security_group_name) retrieve @cluster_sg_rule_int_tcp
    call update_field(@cluster_sg_rule_int_udp, "group_name", $security_group_name) retrieve @cluster_sg_rule_int_udp

    provision(@cluster_sg_rule_int_tcp)
    provision(@cluster_sg_rule_int_udp)
    provision(@cluster_sg_rule_admin)

    call update_field(@cluster_master, "security_group_hrefs", [@cluster_sg]) retrieve @cluster_master
    call update_field(@cluster_node, "security_group_hrefs", [@cluster_sg]) retrieve @cluster_node

    call update_field(@cluster_master, "cloud_specific_attributes", {"root_volume_size" => 100, "root_volume_type_uid" => "gp2"}) retrieve @cluster_master
    call update_field(@cluster_node, "cloud_specific_attributes", {"root_volume_size" => 100, "root_volume_type_uid" => "gp2"}) retrieve @cluster_node
  end

  task_label("Launching master server")

  provision(@cluster_master)

  @@deployment.multi_update_inputs(inputs: {
    'KUBE_CLUSTER_JOIN_CMD': 'cred:' + 'KUBE_' + $execution_id + '_JOIN_CMD'
  })

  task_label("Launching node servers")

  provision(@cluster_node)

  task_label("Finalizing cluster parameters")

  $new_admin_ips = $admin_ip

  if $cloud == "AWS"
    $new_master_ip = @cluster_master.current_instances().public_ip_addresses[0]
  else
    $new_master_ip = @cluster_master.current_instances().private_ip_addresses[0]
  end
end

define terminate(@cluster_master, @cluster_node) return @cluster_master, @cluster_node do
  task_label("Terminating servers")

  # remove servers first to ensure auto_terminate can cleanly remove security groups
  concurrent do
    delete(@cluster_master)
    delete(@cluster_node)
  end
  
  task_label("Removing cluster credentials")
  call kube_get_execution_id() retrieve $execution_id
  $credential_name = "KUBE_" + $execution_id + "_JOIN_CMD"
  @credential = find("credentials", $credential_name)
  @credential.destroy()
end

define resize_cluster(@cluster_node, $node_count_min, $node_count_max) return @cluster_node, $node_count_min, $node_count_max do
  task_label("Updating autoscaling range")

  @cluster_node.update(server_array: {
    "elasticity_params": {
      "bounds": {
        "min_count": $node_count_min,
        "max_count": $node_count_max
      }
    }
  })
end

define add_admin_ip(@cluster_sg, $admin_ip) return $new_admin_ips do
  task_label("Updating security group")

  @new_rule = {
    "namespace": "rs_cm",
    "type": "security_group_rule",
    "fields": {
      "protocol": "tcp",
      "direction": "ingress",
      "source_type": "cidr_ips",
      "security_group_href": @cluster_sg,
      "cidr_ips": join([$admin_ip, '/32']),
      "protocol_details": {
        "start_port": "0",
        "end_port": "65535"
      }
    }
  }

  provision(@new_rule)

  task_label("Updating cluster parameters")

  @ingress_rules = select(@cluster_sg.security_group_rules(), { direction: "ingress" })

  $sg_ips = map $sg_cidr_ip in @ingress_rules.cidr_ips[] return $sg_ip do
    if $sg_cidr_ip
      $sg_ip = first(split($sg_cidr_ip, "/"))
    else
      $sg_ip = null
    end
  end

  $new_admin_ips = join($sg_ips, ", ")
end

define install_hello(@cluster_master, @cluster_node) return @cluster_master, @cluster_node, $node_ip, $hello_port do
  task_label("Installing application")

  call rs_st.run_script_no_inputs(first(@cluster_master.current_instances()), 'Kubernetes Install Hello')

  task_label("Updating cluster parameters")

  $node_ip = @cluster_node.current_instances().public_ip_addresses[0]
  $hello_port = tag_value(first(@cluster_master.current_instances()), "rs_cluster:hello_port")
end

define security_group_name($cloud, @group) return $name do
  if $cloud == "Google"
    $name = @group.resource_uid
  else
    $name = @group.name
  end
end

define update_field(@declaration, $field_name, $field_value) return @declaration do
  $json = to_object(@declaration)
  $json["fields"][$field_name] = $field_value
  @declaration = $json
end

define kube_get_execution_id() return $execution_id do
  $execution_id = last(split(tag_value(@@deployment, "selfservice:href"), "/"))
end
