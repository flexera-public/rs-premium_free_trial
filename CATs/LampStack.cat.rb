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
#x
# DESCRIPTION
# Deploys a basic 3-Tier LAMP Stack.
# 
# FEATURES
# User can select cloud at launch.
# User can use a post-launch action to install a different version of the application software from a Git repo.


name 'F) LAMP Stack'
rs_ca_ver 20160622
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/lamp_icon.png)

Launches a 3-tier LAMP stack."
long_description "Launches a 3-tier LAMP stack.\n
Clouds Supported: <B>AWS, Azure</B>"

import "common/parameters"
import "common/lamp_parameters"
import "common/mappings"
import "common/lamp_mappings"
import "common/conditions"
import "common/resources"
import "common/lamp_resources"
import "util/server_templates"
import "util/server_array"
import "util/err"
import "util/cloud"
import "util/creds"
import "definitions/lamp"

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
  like $server_templates.import_servertemplates
end

####################
# OPERATIONS       #
####################
operation "launch" do 
  description "Concurrently launch the servers" 
  definition "lamp.launcher"
  output_mappings do {
    $site_url => $site_link,
    $lb_status => $lb_status_link,
  } end
end

operation "update_app_code" do
  label "Update Application Code"
  description "Select and install a different repo and branch of code."
  definition "lamp.install_appcode"
end

operation "scale_out" do
  label "Scale Out"
  description "Adds (scales out) an application tier server."
  definition "server_array.scale_out_array"
end

operation "scale_in" do
  label "Scale In"
  description "Scales in an application tier server."
  definition "server_array.scale_in_array"
end





