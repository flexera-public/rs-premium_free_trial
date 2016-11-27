#Copyright 2016 RightScale
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
#x
# DESCRIPTION
# Deploys a basic 3-Tier LAMP Stack.
#
# FEATURES
# User can select cloud at launch.
# User can use a post-launch action to install a different version of the application software from a Git repo.


name 'RL10 LAMP Stack'
rs_ca_ver 20160622
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/lamp_icon.png)

Launches a 3-tier LAMP stack."
long_description "Launches a 3-tier LAMP stack.\n
Clouds Supported: <B>AWS, Azure</B>"

import "pft/parameters"
import "pft/lamp_parameters"
import "pft/mappings"
import "pft/lamp_mappings"
import "pft/conditions"
import "pft/resources"
import "pft/lamp_resources"
import "pft/server_templates_utilities"
import "pft/server_array_utilities"
import "pft/lamp_utilities"

##################
# User inputs    #
##################
parameter "param_location" do
  like $parameters.param_location
end

parameter "param_costcenter" do
  like $parameters.param_costcenter
end

parameter "param_appcode" do
  like $lamp_parameters.param_appcode
  operations "update_app_code"
end


################################
# Outputs returned to the user #
################################
output "site_url" do
  label "Web Site URL"
  category "Output"
  description "Click to see your web site."
end

output "lb_status" do
  label "Load Balancer Status Page"
  category "Output"
  description "Accesses Load Balancer status page"
end

output "app1_github_link" do
  label "Yellow Application Code"
  category "Code Repositories"
  description "\"Yellow\" application repo. (The main change is in the style.css file.)"
  default_value "https://github.com/rightscale/examples/tree/unified_php"
end

output "app2_github_link" do
  label "Blue Application Code"
  category "Code Repositories"
  description "\"Blue\" application repo. (The main change is in the style.css file.)"
  default_value "https://github.com/rs-services/rs-premium_free_trial/tree/unified_php_modified"
end


##############
# MAPPINGS   #
##############

# Mapping and abstraction of cloud-related items.
mapping "map_cloud" do
  like $mappings.map_cloud
end

# Mapping of which ServerTemplates and Revisions to use for each tier.
mapping "map_st" do
  like $lamp_mappings.map_st
end

mapping "map_mci" do
  like $lamp_mappings.map_mci
end

# Mapping of names of the creds to use for the DB-related credential items.
# Allows for easier maintenance down the road if needed.
mapping "map_db_creds" do
  like $lamp_mappings.map_db_creds
end

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
resource 'chef_server', type: 'server' do
  name join(['Chef-',last(split(@@deployment.href,"/"))])
  cloud map( $map_cloud, $param_location, "cloud" )
  datacenter map($map_cloud, $param_location, "zone")
  instance_type map($map_cloud, $param_location, "instance_type")
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  placement_group_href map($map_cloud, $param_location, "pg")
  security_group_hrefs map($map_cloud, $param_location, "sg")
  #server_template find(map($map_st, "lb", "name"), revision: map($map_st, "lb", "rev"))
  server_template_href '/api/server_templates/389019003'
  #multi_cloud_image_href find(map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_name"), revision: map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_rev"))
  multi_cloud_image_href '/api/multi_cloud_images/421984003'
  inputs do {
    'LOG_LEVEL' => 'text:info',
    'EMAIL_FROM_ADDRESS' => 'text:pft@rightscale.com',
    'CHEF_NOTIFICATON_EMAIL' => 'text:ryan@rightscale.com',
    'CHEF_SERVER_FQDN' => 'env:PUBLIC_IP', # Maybe private is better? Maybe we do some DNS here?
    'CHEF_SERVER_VERSION' => 'text:12.11.1',
    'COOKBOOK_VERSION' => 'text:v1.0.3',
    'CHEF_ORG_NAME' => 'text:pft',
    'CHEF_ADMIN_EMAIL' => 'text:ryan@rightscale.com',
    'CHEF_ADMIN_FIRST_NAME' => 'text:Ryan',
    'CHEF_ADMIN_LAST_NAME' => 'text:Geyer',
    'CHEF_ADMIN_USERNAME' => 'text:rgeyer',
    'CHEF_ADMIN_PASSWORD' => 'text:default-pass'
  } end
end

resource 'lb_server', type: 'server' do
  like @lamp_resources.lb_server
end

resource 'db_server', type: 'server' do
  like @lamp_resources.db_server
end

resource 'app_server', type: 'server_array' do
  like @lamp_resources.app_server
end

## TO-DO: Set up separate security groups for each tier with rules that allow the applicable port(s) only from the IP of the given tier server(s)
resource "sec_group", type: "security_group" do
  like @lamp_resources.sec_group
end

resource "sec_group_rule_https", type: "security_group_rule" do
  name "CAT HTTP Rule"
  description "Allow HTTPS access."
  source_type "cidr_ips"
  security_group @lamp_resources.sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "443",
    "end_port" => "443"
  } end
end

resource "sec_group_rule_http", type: "security_group_rule" do
  like @lamp_resources.sec_group_rule_http
end

resource "sec_group_rule_http8080", type: "security_group_rule" do
  like @lamp_resources.sec_group_rule_http8080
end

resource "sec_group_rule_mysql", type: "security_group_rule" do
  like @lamp_resources.sec_group_rule_mysql
end

### SSH Key ###
resource "ssh_key", type: "ssh_key" do
  like @resources.ssh_key
end

### Placement Group ###
resource "placement_group", type: "placement_group" do
  like @resources.placement_group
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
# operation "launch" do
#   description "Concurrently launch the servers"
#   definition "lamp_utilities.launcher"
#   output_mappings do {
#     $site_url => $site_link,
#     $lb_status => $lb_status_link,
#   } end
# end

operation "launch" do
  description "test"
  definition "launch"
end

operation "update_app_code" do
  label "Update Application Code"
  description "Select and install a different repo and branch of code."
  definition "lamp_utilities.install_appcode"
end

operation "scale_out" do
  label "Scale Out"
  description "Adds (scales out) an application tier server."
  definition "server_array_utilities.scale_out_array"
end

operation "scale_in" do
  label "Scale In"
  description "Scales in an application tier server."
  definition "server_array_utilities.scale_in_array"
end

define launch(@ssh_key, @sec_group, @sec_group_rule_http, @sec_group_rule_http8080, @sec_group_rule_mysql, @placement_group, @chef_server, @app_server, @lb_server, @db_server, $needsSshKey, $needsPlacementGroup, $needsSecurityGroup) return @chef_server, @app_server, @lb_server, @db_server do
  if $needsSshKey
    provision(@ssh_key)
  end

  # Provision the security group rules if applicable. (The security group itself is created when the server is provisioned.)
  if $needsSecurityGroup
    provision(@sec_group_rule_http)
    provision(@sec_group_rule_http8080)
    provision(@sec_group_rule_mysql)
  end

  # Provision the placement group if applicable
  if $needsPlacementGroup
      provision(@placement_group)
  end

  provision(@chef_server)
  $key = gsub(gsub(tag_value(@chef_server.current_instance(), 'chef_org_validator:pft'), ',', '\n'), 'eq;', '=')
  $credname = 'PFT-LAMP-ChefValidator-'+last(split(@@deployment.href,"/"))
  rs_cm.credentials.create(credential: {name: $credname, value: $key})

  $cert = gsub(gsub(tag_value(@chef_server.current_instance(), 'chef_server:ssl_cert'), ',', '\n'), 'eq;', '=')
  $credname = 'PFT-LAMP-ChefCert-'+last(split(@@deployment.href,"/"))
  rs_cm.credentials.create(credential: {name: $credname, value: $cert})
end
