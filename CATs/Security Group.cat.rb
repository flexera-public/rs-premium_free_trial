# Copyright 2017 RightScale
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

name 'Security Group'
rs_ca_ver 20160622
short_description "![logo](https://cdn0.iconfinder.com/data/icons/flat-security-icons/512/lock-open-blue.png =64x64)\n
Provisions and manages an SDN-based Security Group."
long_description 'Provisions and manages an SDN-based Security Group within the chosen cloud.'

###
# User inputs
###
parameter 'cloud' do
  label 'Cloud'
  category 'Location'
  default 'EC2 us-east-1'
  description "json:{\"definition\":\"get_cloud_names\", \"description\": \"The cloud the security group will reside in.\"}"
  type 'string'
  min_length 1
end

parameter 'network_name' do
  label 'Network'
  description "json:{\"definition\":\"get_network_names\",\"mapping\":\"param_location_values\",\"key\":\"cloud\",\"parameter\":\"cloud\",\"description\":\"The network to place the security group in.\"}"
  category 'Location'
  default 'EC2 us-east-1: Default'
  type 'string'
  min_length 1
end

parameter 'security_group_name' do
  label 'Security Group Name'
  description 'A name for the security group.'
  category 'Security Group'
  type 'string'
  min_length 1
end

parameter 'security_group_description' do
  label 'Security Group Description'
  description 'A description for the security group.'
  category 'Security Group'
  type 'string'
  min_length 1
end

parameter 'security_group_rule_source_cidr' do
  label 'Source CIDR'
  category 'Security Group Rules'
  default '0.0.0.0/0'
  type 'string'
  allowed_pattern /^([0-9]{1,3}\.){3}[0-9]{1,3}(\/([0-9]|[1-2][0-9]|3[0-2]))?$/
end

parameter 'security_group_rule_http' do
  label 'Allow HTTP (TCP 80)'
  category 'Security Group Rules'
  default 'false'
  type 'string'
  allowed_values 'true', 'false'
end

parameter 'security_group_rule_https' do
  label 'Allow HTTPS (TCP 443)'
  category 'Security Group Rules'
  default 'false'
  type 'string'
  allowed_values 'true', 'false'
end

parameter 'security_group_rule_ssh' do
  label 'Allow SSH (TCP 22)'
  category 'Security Group Rules'
  default 'false'
  type 'string'
  allowed_values 'true', 'false'
end

###
# Resources
###
resource 'security_group', type: 'security_group' do
  name $security_group_name
  description $security_group_description
  cloud $cloud
  # network updated later in launch definition
  network_href 'dummy'
end

resource 'security_group_rule_http', type: 'security_group_rule' do
  description 'Allow HTTP (TCP 80)'
  source_type 'cidr_ips'
  security_group @security_group
  protocol 'tcp'
  direction 'ingress'
  cidr_ips $security_group_rule_source_cidr
  protocol_details do {
    'start_port' => '80',
    'end_port' => '80'
  } end
end

resource 'security_group_rule_https', type: 'security_group_rule' do
  description 'Allow HTTPS (TCP 443)'
  source_type 'cidr_ips'
  security_group @security_group
  protocol 'tcp'
  direction 'ingress'
  cidr_ips $security_group_rule_source_cidr
  protocol_details do {
    'start_port' => '443',
    'end_port' => '443'
  } end
end

resource 'security_group_rule_ssh', type: 'security_group_rule' do
  description 'Allow SSH (TCP 22)'
  source_type 'cidr_ips'
  security_group @security_group
  protocol 'tcp'
  direction 'ingress'
  cidr_ips $security_group_rule_source_cidr
  protocol_details do {
    'start_port' => '22',
    'end_port' => '22'
  } end
end

###
# Local Definitions
###
define audit_log($summary, $details) do
  rs_cm.audit_entries.create(
    notify: "None",
    audit_entry: {
      auditee_href: @@deployment,
      summary: $summary,
      detail: $details
    }
  )
end

define debug_audit_log($summary, $details) do
  if $$debug == true
    rs_cm.audit_entries.create(
      notify: "None",
      audit_entry: {
        auditee_href: @@deployment,
        summary: $summary,
        detail: $details
      }
    )
  end
end

define get_cloud_names() return $values do
  @clouds = rs_cm.clouds.get()
  $clouds = []
  foreach @cloud in @clouds do
    $clouds << @cloud.name
  end
  $values = sort($clouds)
end

define get_network_names() return $values do
  @networks = rs_cm.networks.get()
  $networks = []
  foreach @network in @networks do
    $cloud_href = select(@network.links, {"rel":"cloud"})[0]['href']
    @cloud = rs_cm.get(href: $cloud_href)
    $networks << @cloud.name + ': ' + @network.name
  end
  $values = sort($networks)
end

###
# Launch Definition
###
define provision_security_group($security_group_rule_http, $security_group_rule_https, $security_group_rule_ssh, @security_group, @security_group_rule_http, @security_group_rule_https, @security_group_rule_ssh, $network_name) return @security_group, @security_group_rule_http, @security_group_rule_https, @security_group_rule_ssh do
  sub task_label: 'Provisioning security group' do
    # update the resource (remove the cloud prefix from the network name)
    $json = to_object(@security_group)
    $network = strip(split($network_name, ':')[1])
    $json['fields']['network_href'] = null
    $json['fields']['network'] = $network
    @security_group = $json

    provision(@security_group)
  end

  sub task_label: 'Provisioning security group rules' do
    if $security_group_rule_http == 'true'
      provision(@security_group_rule_http)
    end

    if $security_group_rule_https == 'true'
      provision(@security_group_rule_https)
    end

    if $security_group_rule_ssh == 'true'
      provision(@security_group_rule_ssh)
    end
  end
end

###
# Operations
###
operation 'launch' do
  description 'Create and manage Security Group.'
  definition 'provision_security_group'
  label 'Launch'
end
