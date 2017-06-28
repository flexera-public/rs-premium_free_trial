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
# Store the API keys in CREDENIALs and use cred: in inputs instead of current clear text approach.
# Support more clouds. This would require coordinating with the ST author to add images in other clouds.

name 'F) Rancher Cluster'
rs_ca_ver 20161221
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/rancher_logo.png) ![logo](https://s3.amazonaws.com/rs-pft/cat-logos/docker.png)

Launches a Rancher cluster of Docker hosts."
long_description "Launches a Rancher cluster.\n
Clouds Supported: <B>AWS</B>"

import "pft/mappings"
import "pft/conditions"
import "pft/resources", as: "common_resources"
import "pft/server_templates_utilities"
import "pft/cloud_utilities"
import "pft/err_utilities"

##################
# User inputs    #
##################
parameter "param_location" do 
  category "Cluster Options"
  label "Cloud" 
  type "string" 
  allowed_values "AWS"  #, "Google" 
  default "AWS"
end

parameter 'param_qty' do
  category "Cluster Options"
  type 'number'
  label 'Number of Rancher Hosts'
  description 'Enter a value from 1 to 10.'
  min_value 1
  max_value 10
  default 3
end

parameter "num_add_nodes" do
  category "Cluster Options"
  type "number"
  label "Number of Rancher Hosts to Add to the Cluster"
  description "Enter the number of hosts you want to add to the cluster."
  default 1
end

parameter 'app_stack' do
  category "Stack Deployment"
  type "string"
  label "Application Stack"
  description "Select an application stack to launch on the Rancher Cluster."
  allowed_values "WordPress", "Nginx" #, "ElasticSearch"
  default "WordPress"
end

parameter 'app_stack_name' do
  category "Stack Deployment"
  type "string"
  label "Application Stack Name"
  description "Enter a unique name for the application stack."
  allowed_pattern '^[a-z0-9]+(\-*[a-z0-9]+)*$'
  min_length 1
  constraint_description "Names must be lower case and can include numbers, and \"-\" are allowed."
end

################################
# Outputs returned to the user #
################################

output "rancher_ui_link" do
  category "Rancher UI Access"
  label "Rancher UI Link"
  description "Click to access the Rancher UI.(NOTE: username/passsword = \"rightscale\")"
end

output "rancher_infra_link" do
  category "Rancher UI Access"
  label "Rancher Infrastructure Page"
  description "Click to see the Rancher Cluster infrastructure."
end

[*1..10].each do |n|
  output "app_#{n}_name" do
    label "Application Name"
    category "Application #{n}"
  end
end

[*1..10].each do |n|
  output "app_#{n}_graph" do
    label "Application Graph"
    category "Application #{n}"
  end
end

[*1..10].each do |n|
  output "app_#{n}_link" do
    label "Application Link"
    category "Application #{n}"
  end
end

[*1..10].each do |n|
  output "app_#{n}_code" do
    label "Application Rancher and Docker Compose Code"
    category "Application #{n}"
  end
end

##############
# MAPPINGS   #
##############

# Mapping and abstraction of cloud-related items.
mapping "map_cloud" do 
  like $mappings.map_cloud
end

# Mapping of which ServerTemplates and Revisions to use for each tier.
mapping "map_st" do {
  "server" => {
    "name" => "Rancher Server",
    "rev" => "30", # previous "21", # previous: 17
  },
  "host" => {
    "name" => "Rancher Host",
    "rev" => "20", # previous "10", # previous: 7
  },
} end

mapping "map_mci" do {
  "VMware" => { # vSphere 
    "mci_name" => "NA",
    "mci_rev" => "NA",
  },
  "Public" => { # all other clouds
    "mci_name" => "Ubuntu_14.04_x64",
    "mci_rev" => "55", # previous "20", # previous: 13
  }
} end



##################
# CONDITIONS     #
##################

# Used to decide whether or not to pass an SSH key or security group when creating the servers.
condition "needsSshKey" do
  like $conditions.needsSshKey
end

condition "needsSecurityGroup" do
  like $conditions.needsSecurityGroup
end

condition "needsPlacementGroup" do
  like $conditions.needsPlacementGroup
end

condition "invSphere" do
  like $conditions.invSphere
end

condition "inAzure" do
  like $conditions.inAzure
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
#  multi_cloud_image_href find(map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_name"), revision: map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_rev"))
  inputs do {
    "RANCHER_HOST_PORT" => "text:8080",
    # Set the Route53 inputs to not use it.
    "ROUTE_53_UPDATE_RECORD" => "text:false",
    "ROUTE_53_AWS_ACCESS_KEY_ID" => "text:unused",
    "ROUTE_53_AWS_SECRET_ACCESS_KEY" => "text:unused",
    "NEW_RELIC_LICENSE_KEY" => "text:unused"  # No New Relic configured but key placeholder needed
  } end
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
#  multi_cloud_image_href find(map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_name"), revision: map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_rev"))
  inputs do {
    # Set the Route53 inputs to not use it.
    "ROUTE_53_UPDATE_RECORD" => "text:false",
    "ROUTE_53_AWS_ACCESS_KEY_ID" => "text:unused",
    "ROUTE_53_AWS_SECRET_ACCESS_KEY" => "text:unused",
    "NEW_RELIC_LICENSE_KEY" => "text:unused"  # No New Relic configured but key placeholder needed
  } end  
  # Server Array Settings
  state "enabled"
  array_type "alert"
  elasticity_params do {
    "bounds" => {
      "min_count"            => $param_qty,
      "max_count"            => 10
    },
    "pacing" => {
      "resize_calm_time"     => 30, 
      "resize_down_by"       => 1,
      "resize_up_by"         => 1
    },
    "alert_specific_params" => {
      "decision_threshold"   => 51,
      "voters_tag_predicate" => "Rancher Host"
    }
  } end
end

### Security Group Definitions ###
resource "sec_group", type: "security_group" do
  like @common_resources.sec_group
end

resource "sec_group_rule_ssh", type: "security_group_rule" do
  like @common_resources.sec_group_rule_ssh
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
  like @common_resources.ssh_key
end


##################
# Permissions    #
##################
permission "import_servertemplates" do
  like $server_templates_utilities.import_servertemplates
end

####################
# OPERATIONS       #
####################
operation 'launch' do 
  description 'Launch the application' 
  definition 'launch_cluster' 
  output_mappings do {
    $rancher_ui_link => $rancher_ui_uri,
    $rancher_infra_link => $rancher_infra_uri,
  } end
end 

operation 'enable' do
  description 'Enable an application stack on the Rancher cluster.'
  definition 'deploy_stack'

  hash = {}
  [*1..10].each do |n|
    hash[eval("$app_#{n}_name")] = switch(get(n,$app_names),  get(0,get(n,$app_names)), "")
    hash[eval("$app_#{n}_link")] = switch(get(n,$app_links),  get(0,get(n,$app_links)), "")
    hash[eval("$app_#{n}_graph")] = switch(get(n,$app_graphs),  get(0,get(n,$app_graphs)), "")
    hash[eval("$app_#{n}_code")] = switch(get(n,$app_codes),  get(0,get(n,$app_codes)), "")
  end

  output_mappings do 
    hash
  end
end

operation 'launch_app_stack' do
  label 'Launch an Application Stack'
  description "Launch an application stack"
  definition "deploy_stack"
  
  hash = {}
  [*1..10].each do |n|
    hash[eval("$app_#{n}_name")] = switch(get(n,$app_names),  get(0,get(n,$app_names)), "")
    hash[eval("$app_#{n}_link")] = switch(get(n,$app_links),  get(0,get(n,$app_links)), "")
    hash[eval("$app_#{n}_graph")] = switch(get(n,$app_graphs),  get(0,get(n,$app_graphs)), "")
    hash[eval("$app_#{n}_code")] = switch(get(n,$app_codes),  get(0,get(n,$app_codes)), "")
  end

  output_mappings do 
    hash
  end
end

operation 'delete_app_stack' do
  label 'Delete an Application Stack'
  description "Delete an application stack"
  definition "delete_stack"
  hash = {}
  [*1..10].each do |n|
    hash[eval("$app_#{n}_name")] = switch(get(n,$app_names),  get(0,get(n,$app_names)), "")
    hash[eval("$app_#{n}_link")] = switch(get(n,$app_links),  get(0,get(n,$app_links)), "")
    hash[eval("$app_#{n}_graph")] = switch(get(n,$app_graphs),  get(0,get(n,$app_graphs)), "")
    hash[eval("$app_#{n}_code")] = switch(get(n,$app_codes),  get(0,get(n,$app_codes)), "")
  end

  output_mappings do 
    hash
  end
end

operation "add_nodes" do
  label "Add Nodes to Rancher Cluster"
  description "Adds (scales out) an application tier server."
  definition "add_nodes"
end

##########################
# DEFINITIONS (i.e. RCL) #
##########################
define launch_cluster(@rancher_server, @rancher_host, @ssh_key, @sec_group, @sec_group_rule_http8080, @sec_group_rule_http80, @sec_group_rule_http443, @sec_group_rule_ssh, @sec_group_rule_udp500, @sec_group_rule_udp4500, $map_cloud, $param_location, $map_st, $needsSshKey, $needsSecurityGroup)  return @rancher_server, @rancher_host, @ssh_key, @sec_group, @sec_group_rule_http8080, @sec_group_rule_http80, @sec_group_rule_http443, @sec_group_rule_ssh, @sec_group_rule_udp500, @sec_group_rule_udp4500, $rancher_ui_uri, $rancher_infra_uri  do 
  
  # Need the cloud name later on
  $cloud_name = map( $map_cloud, $param_location, "cloud" )

  # Check if the selected cloud is supported in this account.
  # Since different PIB scenarios include different clouds, this check is needed.
  # It raises an error if not which stops execution at that point.
  #call cloud_utilities.checkCloudSupport($cloud_name, $param_location)
  
  # Find and import the server template - just in case it hasn't been imported to the account already
  call server_templates_utilities.importServerTemplate($map_st)
  
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
  
  # construct the rancher server URL to be used by the Hosts
  $rancher_server_ip = @rancher_server.current_instance().public_ip_addresses[0]
  $rancher_ui_uri = join(["http://", $rancher_server_ip, ":8080/"])
  $rancher_infra_uri = join([$rancher_ui_uri, "env/1a5/infra/hosts"])
  
  # Test the API to make sure the server is ready
  call rancher_api(@rancher_server, "get", "/v1", "body") retrieve $body
  while (type($body)  == 'string') do
    call err_utilities.log("debug:  check api response type", to_s(type($body)))
    call err_utilities.log("debug:  check api response contents", to_s(inspect($body)))
    sleep(15)
    call rancher_api(@rancher_server, "get", "/v1", "body") retrieve $body
  end

  # Get the keys from the API
  call rancher_api(@rancher_server, "post", "/v1/projects/1a5/apikeys", "body") retrieve $body
#  call err_utilities.log("debug: apikeys response type", to_s(type($body)))
  
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
  
  # Now enable local authentication with username and password = rightscale
  # NOT DOING THIS AT THIS TIME. 
  # Creating the local user forces the user to pick an environment the first time they login to the Rancher UI which may confuse folks.
  # The other edge of this sword though is that no creating a local user causes a little red ! to be shown on the UI since there is no access control.
  # But from a easy-to-use perspective, that's the best option.
  #call enable_rancher_auth(@rancher_server, "rightscale", "rightscale")
   

end 

define deploy_stack(@rancher_server, $app_stack, $app_stack_name) return $app_names, $app_links, $app_graphs, $app_codes do
  
  # Nothing special has been done to use load balancers and things like that.
  # So the number of apps supported is limited to the number of hosts in the cluster.
  # So check the numbers and raise an error if there is a problem.
  $num_rancher_hosts = size(@@deployment.server_arrays().current_instances())  
  call get_appstack_tags() retrieve $app_stacks_hash
  $num_apps = size($app_stacks_hash)
  $app_names = []
  $app_links = []
  $app_graphs = []
  $app_codes = []
    
  # Do some checks before trying to launch the application stack.
  # TODO: store the app list outputs such that you don't have to crawl the Rancher API to rebuild the outputs each time.
  if ($num_apps >= $num_rancher_hosts)
    call get_current_app_lists() retrieve $app_names, $app_links, $app_graphs, $app_codes
    raise "Rancher stack limit reached. Either delete an application stack or add Rancher hosts before launching another stack."
  elsif contains?(keys($app_stacks_hash), [$app_stack_name])
    call get_current_app_lists() retrieve $app_names, $app_links, $app_graphs, $app_codes
    raise "Rancher stack name already exists. Launch rancher stack with a unique name."
  end
  
  # If we get this far, then we need to try to launch the application stack.
  $stack_name = $app_stack_name
  $public_service = "tbd" # This is the service in the stack that has public URL access
  
# WORDPRESS
  if $app_stack == "WordPress"
    
    # the docker_compose service that has public access ports
    $public_service = "wordpress"  
    
    # set up the compose files for the WordPress stack
    $docker_compose = 
'wordpress:
  image: wordpress
  links:
  - db:mysql
  ports:
  - 80:80/tcp
db:
  image: mariadb
  environment:
    MYSQL_ROOT_PASSWORD: example'
    
    $rancher_compose =
'wordpress:
  scale: 1
  start_on_create: true
db:
  scale: 1
  start_on_create: true'   

# NGINX
  elsif $app_stack == "Nginx"
    
    $public_service = "nginx"

    # set up the compose files for the nginx stack
    $docker_compose = 
'nginx:
      ports:
      - 80:80
      restart: always
      tty: true
      image: nginx
      stdin_open: true'
    
    $rancher_compose =
'nginx:
      scale: 1'
    
# Oops
  else
    raise "Unknown application stack selected: " + $app_stack
  end
  
  # Launch the stack on the Rancher server
  call launch_stack(@rancher_server, $stack_name, $docker_compose, $rancher_compose) 

  # Store the stack info as tags
  call maintain_app_stack_info("add", $app_stack_name, $public_service)
  
  # Now get the list of applications to output - do this each time to account for any changes and shuffling of load balancers
  call get_app_lists(@rancher_server) retrieve $app_names, $app_links, $app_graphs, $app_codes
  
end

# Runs the provided docker and rancher compose files on the cluster
define launch_stack(@rancher_server, $stack_name, $docker_compose, $rancher_compose) do
  
  # set up the inputs with the rancher compose and docker compose YAML consumed by Rancher to launch a stack.
  $inp = {
    'RANCHER_COMPOSE_PROJECT_NAME':join(['text:', $stack_name]),
    'RANCHER_COMPOSE_DOCKER_YAML':join(['text:', $docker_compose]),     
    'RANCHER_COMPOSE_RANCHER_YAML':join(['text:', $rancher_compose])
  }
    
  call server_templates_utilities.run_script_inputs(@rancher_server, "Run rancher-compose", $inp)
  
end

# Delete specified application stack
define delete_stack(@rancher_server, $app_stack_name) return $app_names, $app_links, $app_graphs, $app_codes do
  
  call rancher_api(@rancher_server, "get", "/v1/projects", "data") retrieve $data_section
  $envs_url = $data_section[0]["links"]["environments"]
    
  call rancher_api(@rancher_server, "get", $envs_url, "data") retrieve $env_array

  foreach $env_spec in $env_array do
    $env_name = $env_spec["name"]
    if $env_name == $app_stack_name
      $env_remove_link = $env_spec["actions"]["remove"]
      call rancher_api(@rancher_server, "delete", $env_remove_link, "body") retrieve $response
    end  
  end
  
  $appstack_deleted = false 
  while logic_not($appstack_deleted) do 
   sleep(5) # give the cluster a few seconds to clean up   
   $appstack_deleted = true # assume the best    
   call rancher_api(@rancher_server, "get", $envs_url, "data") retrieve $env_array
   foreach $env_spec in $env_array do
        $env_name = $env_spec["name"]
        if $env_name == $app_stack_name  # the app (i.e environment) is still being cleaned up
          $appstack_deleted = false
        end
   end
  end
  
  # Remove the app stack from the deployment tags 
  call maintain_app_stack_info("delete", $app_stack_name, "na")

  # Now get the list of applications to output - do this each time to account for any changes and shuffling of load balancers
  call get_app_lists(@rancher_server) retrieve $app_names, $app_links, $app_graphs, $app_codes
  
end

# Add hosts to the cluster
define add_nodes(@rancher_host, $num_add_nodes) do
  @task = @rancher_host.launch(count:$num_add_nodes)  
  
  sleep(90) # Give the servers a chance to get started before checking for states and problems
  
  $wake_condition = "/^(operational|stranded|stranded in booting|stopped|terminated|inactive|error)$/"
  sleep_until all?(@rancher_host.current_instances().state[], $wake_condition)
  
  call err_utilities.log("instance states after waking", to_s(@rancher_host.current_instances().state[]))

  if !all?(@rancher_host.current_instances().state[], "operational")
    raise "Some instances failed to start"    
  end
end

# Gather up the cloud app outputs to rebuild outputs 
define get_current_app_lists() return $app_names, $app_links, $app_graphs, $app_codes do
   @execution_expanded = @@execution.get(view:"expanded")
   $execution_expanded = to_object(@execution_expanded)
   $outputs = $execution_expanded["details"][0]["outputs"]
   $app_names = [["placeholder"]]
   $app_links = [["placeholder"]]
   $app_graphs = [["placeholder"]]
   $app_codes = [["placeholder"]]
   foreach $output in $outputs do
     if $output["value"] != null
       $output_value = $output["value"]["value"]
       if $output_value != ""
         $output_name = $output["name"]
         if $output_name =~ /app_[0-9]+_name/
           $app_names << [$output_value]
         elsif $output_name =~ /app_[0-9]+_link/
           $app_links << [$output_value]
         elsif $output_name =~ /app_[0-9]+_graph/
           $app_graphs << [$output_value]
         elsif $output_name =~ /app_[0-9]+_code/
           $app_codes << [$output_value]
         end
       end
     end
   end
#   call err_utilities.log("app_names array:", to_s($app_names))
end

# use the Rancher Server API to gather up information about what stacks are running on the cluster
define get_app_lists(@rancher_server) return $app_names, $app_links, $app_graphs, $app_codes do
  
  # Seed the array for output later
  $app_names = [["placeholder"]]
  $app_links = [["placeholder"]]
  $app_graphs = [["placeholder"]]
  $app_codes = [["placeholder"]]
    
  # Gather up the application stack info stored as tags on the deployment.
  # This is used to find the application stacks from Rancher and get the URL for accessing the stack. 
  call get_appstack_tags() retrieve $app_stacks_hash

  # Get the rancher server's url - needed to construct the Rancher UI links for each app   
  $rancher_server_ip = @rancher_server.current_instance().public_ip_addresses[0]
  $rancher_ui_uri = join(["http://", $rancher_server_ip, ":8080"])
  
  # Environments = Application Stacks in Rancher
  # Get list of application stacks
  call rancher_api(@rancher_server, "get", "/v1/projects", "data") retrieve $projects 
  $project_id = $projects[0]["id"]
  $envs_url = $projects[0]["links"]["environments"]
  call rancher_api(@rancher_server, "get", $envs_url, "data") retrieve $envs_array

  # Make sure there is at least one stack deployed on the cluster
  if logic_not(empty?($envs_array))  
    
    # Go through each application and gather up the information
    foreach $env_spec in $envs_array do
      
      # Get the stack name
      $app_name = $env_spec["name"]
        
      # Is the environment (i.e. application) returned by rancher one we care about?
      if (contains?(keys($app_stacks_hash), [$app_name]))
        # Get the Rancher ID for the stack and create a couple of Rancher UI links for the app
        $app_id = $env_spec["id"]
        $app_ui_base_path = join([$rancher_ui_uri, "/env/",$project_id, "/apps/stacks/",$app_id])
        $app_graph = join([$app_ui_base_path, "/graph"])
        $app_code = join([$app_ui_base_path, "/code"])
     
        $app_access_host_ip_address = ""
     
        # Now drill through the API to get the IP/link to the application stack
          
        # Loop through the services launched for the given stack
        $app_services_url = $env_spec["links"]["services"]
         
        call check_app_service_is_ready($app_services_url, $app_stacks_hash[$app_name]) retrieve $app_service
        
        $app_access_service_instance_url = $app_service["links"]["instances"]
        call rancher_api(@rancher_server, "get", $app_access_service_instance_url, "data") retrieve $app_access_service_instance
#        call err_utilities.log("app_access_service_instance:", to_s($app_access_service_instance))
        
        $app_access_service_host_url = $app_access_service_instance[0]["links"]["hosts"]
        call rancher_api(@rancher_server, "get", $app_access_service_host_url, "data") retrieve $app_access_service_host
#        call err_utilities.log("app_access_service_host:", to_s($app_access_service_host))
        
        $app_access_service_host_ip_url = $app_access_service_host[0]["links"]["ipAddresses"]
        call rancher_api(@rancher_server, "get", $app_access_service_host_ip_url, "data") retrieve $app_access_service_host_ip_info
#        call err_utilities.log("app_access_service_host_ip_info:", to_s($app_access_service_host_ip_info))
        
        # Here's the Easter egg we've been searching for
        $app_access_host_private_ip_address = $app_access_service_host_ip_info[0]["address"]
#        call err_utilities.log("app_access_host_ip_address: "+$app_access_host_private_ip_address, "")
        # But this is the private IP address - the rancher host doesn't seem to know about the public IPs
        # So find the public IP
        call get_host_public_ip($app_access_host_private_ip_address) retrieve $app_access_host_ip_address
    
        $app_link = "http://" + $app_access_host_ip_address
#        call err_utilities.log("app_link: "+$app_link, "")
          
        $app_names << [$app_name]
        $app_links << [$app_link]
        $app_graphs << [$app_graph]
        $app_codes << [$app_code]
      end    
    end
  else # no stacks so just put some empty data in there
    $app_names << [""]
    $app_links << [""]
    $app_graphs << [""]
    $app_codes << [""]
  end

end

# Creates a local username/password on the Rancher Server
# This is mostly done to get rid of the annoying banner about no access configured.
define enable_rancher_auth(@rancher_server, $username, $password) do
  $post_body = {
     "type": "localAuthConfig",
     "accessMode": "unrestricted",
     "enabled": true,
     "name": "RightScale",
     "username": $username,
     "password": $password
     }
     
  $rancher_server_ip = @rancher_server.current_instance().public_ip_addresses[0]
  $rancher_ui_uri = join(["http://", $rancher_server_ip, ":8080"])
  $api_url = join([$rancher_ui_uri, "/v1/localauthconfigs"])
  
  $response = http_post(
    url: $api_url,
    headers: { "Content-Type": "application/json"},
    body: $post_body
  )
end

# Calls the Rancher API and returns the whole "body" of the response or just the "data" section
define rancher_api(@rancher_server, $action, $api_uri, $message_part_returned) return $api_response do
  
  
  if $api_uri =~ "(http)"  # then we have the full url already
    $api_url = $api_uri
  else # we need to construct it
    # Get the rancher server's IP address    
    $rancher_server_ip = @rancher_server.current_instance().public_ip_addresses[0]
    $rancher_ui_uri = join(["http://", $rancher_server_ip, ":8080"])
    $api_url = join([$rancher_ui_uri, $api_uri])
  end 
  
  # Set up basic auth credentials in case user has enabled access control via the Rancher UI
  $inputs_array = @rancher_server.current_instance().inputs()
  $inputs = $inputs_array[0]
  $username = "tbd"
  $password = "tbd"
  foreach $input in $inputs do
    if $input["name"] == "RANCHER_COMPOSE_ACCESS_KEY" && split($input["value"], ":")[1]
        $username = split($input["value"], ":")[1]
    elsif $input["name"] == "RANCHER_COMPOSE_SECRET_KEY" && split($input["value"], ":")[1]
      $password = split($input["value"], ":")[1]
    end
  end
  
  # Call the rancher server API 
  if $action == "post"
    $response = http_post(
      url: $api_url,
      headers: { "Content-Type": "application/json"},
      basic_auth: { username: $username, password: $password }
    )
  elsif $action == "get"
    $response = http_get(
      url: $api_url,
      headers: { "Content-Type": "application/json"},
      basic_auth: { username: $username, password: $password }
    )
  elsif $action == "delete"
    $response = http_delete(
      url: $api_url,
      headers: { "Content-Type": "application/json"},
      basic_auth: { username: $username, password: $password }
      )
  else 
    raise "Unknown API action: " + $action
  end
  
  $api_response = $response["body"]
    
  if $message_part_returned == "data" # drill further into the response and return the data section
    $api_response = $api_response["data"]
  end

end


# Sometimes there's a race condition with the CAT gathering up the application list and the services really be ready.
# So this function gets the app_services checks to make sure the services are ready.
define check_app_service_is_ready($app_services_url, $service_of_interest) return $app_service_of_interest do
  $not_ready = true
  $app_service_of_interest = ""
  while $not_ready do
    call rancher_api(@rancher_server, "get", $app_services_url, "data") retrieve $app_services      
    foreach $app_service in $app_services do
      if $app_service["name"] == $service_of_interest && $app_service["state"] == "active"
        $app_service_of_interest = $app_service
        $not_ready = false
      end
    end
  end
end

# Gather up the application stack info stored as tags on the deployment.
define get_appstack_tags() return $app_stacks_hash do
  $tags = rs_cm.tags.by_resource(resource_hrefs: [@@deployment.href])
  $all_tags_array = $tags[0][0]['tags']
  $app_stacks_hash = {}
  foreach $tag_item in $all_tags_array do
    $tag = $tag_item["name"]
    if $tag =~ /rancher_stack_info/
      $tag_key_value = split($tag, ":")[1]
      $tag_key = split($tag_key_value, "=")[0]
      $tag_value = split($tag_key_value, "=")[1]
      $app_stack_hash = {$tag_key : $tag_value}
      $app_stacks_hash = $app_stacks_hash + $app_stack_hash
    end
  end
end

# Used to store launched stack info as tags on the deployment
define maintain_app_stack_info($action, $stack_name, $public_service) do
  if ($action == "add")
 
    $tag = "rancher_stack_info:"+$stack_name+"="+$public_service
    rs_cm.tags.multi_add(resource_hrefs: [@@deployment.href], tags: [$tag])

  elsif ($action == "delete")
    
    $public_service = tag_value(@@deployment, "rancher_stack_info:"+$stack_name)
    $tag = "rancher_stack_info:"+$stack_name+"="+$public_service
    rs_cm.tags.multi_delete(resource_hrefs: [@@deployment.href], tags: [$tag])

  else
    raise "maintain_app_stack_info: Unknown action."
  end
end

# look at the servers in the host array with the given private IP address and return the public IP
define get_host_public_ip($app_access_host_private_ip_address) return $app_access_host_ip_address do
  $app_access_host_ip_address = $app_access_host_private_ip_address # will be updated with public ip below
  @server_array_instances = @@deployment.server_arrays().current_instances()
  
  foreach @instance in @server_array_instances do
    if @instance.private_ip_addresses[0] == $app_access_host_private_ip_address
      $app_access_host_ip_address = @instance.public_ip_addresses[0]
    end
  end
end


