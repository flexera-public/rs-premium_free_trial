name "LIB - Common LAMP resources RL10"
rs_ca_ver 20160622
short_description "Resources that are commonly used in LAMP CATs"

package "pft/rl10/lamp_resources"

import "pft/mappings"
import "pft/rl10/lamp_mappings", as: "lamp_mappings"
import "pft/conditions"
import "pft/parameters"
import "pft/rl10/lamp_parameters"

### Server Declarations ###
resource 'chef_server', type: 'server' do
  name join(['Chef-',last(split(@@deployment.href,"/"))])
  cloud map( $map_cloud, $param_location, "cloud" )
  datacenter map($map_cloud, $param_location, "zone")
  instance_type map($map_cloud, $param_location, "instance_type")
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  placement_group_href map($map_cloud, $param_location, "pg")
  security_group_hrefs map($map_cloud, $param_location, "sg")
  server_template find(map($map_st, "chef", "name"), revision: map($map_st, "chef", "rev"))
  multi_cloud_image_href find(map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_name"), revision: map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_rev"))
  network map($map_cloud, $param_location, "network")
  subnets [map($map_cloud, $param_location, "subnet")]
  inputs do {
    'LOG_LEVEL' => 'text:info',
    'EMAIL_FROM_ADDRESS' => 'text:pft@rightscale.com',
    'CHEF_NOTIFICATON_EMAIL' => 'text:pft@rightscale.com',
    'CHEF_SERVER_FQDN' => 'env:PUBLIC_IP', # Maybe private is better? Maybe we do some DNS here?
    'CHEF_SERVER_VERSION' => 'text:12.11.1',
    'COOKBOOK_VERSION' => 'text:v1.0.4',
    'CHEF_ORG_NAME' => 'text:pft',
    'CHEF_ADMIN_EMAIL' => 'text:pft@rightscale.com',
    'CHEF_ADMIN_FIRST_NAME' => 'text:Premium',
    'CHEF_ADMIN_LAST_NAME' => 'text:FreeTrial',
    'CHEF_ADMIN_USERNAME' => 'text:admin',
    'CHEF_ADMIN_PASSWORD' => join(['text:',$param_chef_password])
  } end
end

resource 'lb_server', type: 'server' do
  name join(['LB-',last(split(@@deployment.href,"/"))])
  cloud map( $map_cloud, $param_location, "cloud" )
  datacenter map($map_cloud, $param_location, "zone")
  instance_type map($map_cloud, $param_location, "instance_type")
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  placement_group_href map($map_cloud, $param_location, "pg")
  security_group_hrefs map($map_cloud, $param_location, "sg")
  server_template find(map($map_st, "lb", "name"), revision: map($map_st, "lb", "rev"))
  multi_cloud_image_href find(map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_name"), revision: map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_rev"))
  network map($map_cloud, $param_location, "network")
  subnets [map($map_cloud, $param_location, "subnet")]
  inputs do {
    'BALANCE_ALGORITHM' => 'text:roundrobin',
    'CHEF_ENVIRONMENT' => 'text:_default',
    'CHEF_SERVER_SSL_CERT' => join(['cred:PFT-LAMP-ChefCert-',last(split(@@deployment.href,"/"))]),
    'CHEF_SERVER_URL' => 'text:https://1.1.1.1/organizations/pft',
    'CHEF_VALIDATION_KEY' => join(['cred:PFT-LAMP-ChefValidator-',last(split(@@deployment.href,"/"))]),
    'CHEF_VALIDATION_NAME' => 'text:pft-validator',
    'DELETE_NODE_ON_TERMINATE' => 'text:true',
    'ENABLE_AUTO_UPGRADE' => 'text:true',
    'HEALTH_CHECK_URI' => 'text:/',
    'LOG_LEVEL' => 'text::info',
    'MANAGED_LOGIN' => 'text:auto',
    'MONITORING_METHOD' => 'text:auto',
    'POOLS' => 'text:pft',
    'SCHEDULE_ENABLE' => 'text:true',
    'SCHEDULE_INTERVAL' => 'text:15',
    'SESSION_STICKINESS' => 'text:true',
    'STATUS_URI' => 'text:/haproxy-status',
    'UPGRADES_FILE_LOCATION' => 'text:https://rightlink.rightscale.com/rightlink/upgrades'
  } end
end

resource 'db_server', type: 'server' do
  like @lb_server

  name join(['DB-',last(split(@@deployment.href,"/"))])
  server_template find(map($map_st, "db", "name"), revision: map($map_st, "db", "rev"))
  inputs do {
    'APPLICATION_DATABASE_NAME' => 'text:app_test',
    'APPLICATION_PASSWORD' => 'cred:CAT_MYSQL_APP_PASSWORD',
    'APPLICATION_USER_PRIVILEGES' => 'array:["text:select","text:update","text:insert"]',
    'APPLICATION_USERNAME' => 'cred:CAT_MYSQL_APP_USERNAME',
    'DB_BACKUP_KEEP_DAILIES' => 'text:14',
    'DB_BACKUP_KEEP_LAST' => 'text:60',
    'DB_BACKUP_KEEP_MONTHLIES' => 'text:12',
    'DB_BACKUP_KEEP_WEEKLIES' => 'text:14',
    'DB_BACKUP_KEEP_YEARLIES' => 'text:2',
    'DB_BACKUP_LINEAGE' => 'text:pft',
    'BIND_NETWORK_INTERFACE' => 'text:private',
    'CHEF_ENVIRONMENT' => 'text:_default',
    'CHEF_SERVER_SSL_CERT' => join(['cred:PFT-LAMP-ChefCert-',last(split(@@deployment.href,"/"))]),
    'CHEF_SERVER_URL' => 'text:https://1.1.1.1/organizations/pft',
    'CHEF_VALIDATION_KEY' => join(['cred:PFT-LAMP-ChefValidator-',last(split(@@deployment.href,"/"))]),
    'CHEF_VALIDATION_NAME' => 'text:pft-validator',
    'CHEF_SSL_VERIFY_MODE' => 'text::verify_none',
    'DELETE_NODE_ON_TERMINATE' => 'text:true',
    'DEVICE_COUNT' => 'text:2',
    'DEVICE_DESTROY_ON_DECOMMISSION' => 'text:false',
    'DEVICE_FILESYSTEM' => 'text:ext4',
    'DEVICE_MOUNT_POINT' => 'text:/mnt/storage',
    'DEVICE_NICKNAME' => 'text:data_storage',
    'ENABLE_AUTO_UPGRADE' => 'text:true',
    'EPHEMERAL_FILESYSTEM' => 'text:ext4',
    'EPHEMERAL_LOGICAL_VOLUME_NAME' => 'text:ephemeral0',
    'EPHEMERAL_LOGICAL_VOLUME_SIZE' => 'text:100%VG',
    'EPHEMERAL_MOUNT_POINT' => 'text:/mnt/ephemeral',
    'EPHEMERAL_STRIPE_SIZE' => 'text:512',
    'EPHEMERAL_VOLUME_GROUP_NAME' => 'text:vg-data',
    'LOG_LEVEL' => 'text::info',
    'MANAGED_LOGIN' => 'text:auto',
    'MONITORING_METHOD' => 'text:auto',
    'SCHEDULE_HOUR' => 'text:23',
    'SCHEDULE_MINUTE' => 'text:15',
    'SERVER_USAGE' => 'text:dedicated',
    'SERVER_ROOT_PASSWORD' => 'cred:CAT_MYSQL_ROOT_PASSWORD',
    'SERVER_REPL_PASSWORD' => 'cred:CAT_MYSQL_ROOT_PASSWORD',
    'UPGRADES_FILE_LOCATION' => 'text:https://rightlink.rightscale.com/rightlink/upgrades'
  } end
end

resource 'app_server', type: 'server_array' do
  name join(['App-',last(split(@@deployment.href,"/"))])
  cloud map( $map_cloud, $param_location, "cloud" )
  datacenter map($map_cloud, $param_location, "zone")
  instance_type map($map_cloud, $param_location, "instance_type")
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  placement_group_href map($map_cloud, $param_location, "pg")
  security_group_hrefs map($map_cloud, $param_location, "sg")
  multi_cloud_image_href find(map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_name"), revision: map($map_mci, map($map_cloud, $param_location, "mci_mapping"), "mci_rev"))
  server_template find(map($map_st, "app", "name"), revision: map($map_st, "app", "rev"))
  network map($map_cloud, $param_location, "network")
  subnets [map($map_cloud, $param_location, "subnet")]
  inputs do {
    'APPLICATION_NAME' => 'text:pft',
    'APPLICATION_ROOT_PATH' => 'text:pft',
    'BIND_NETWORK_INTERFACE' => 'text:private',
    'CHEF_ENVIRONMENT' => 'text:_default',
    'CHEF_SERVER_SSL_CERT' => join(['cred:PFT-LAMP-ChefCert-',last(split(@@deployment.href,"/"))]),
    'CHEF_SERVER_URL' => 'text:https://1.1.1.1/organizations/pft',
    'CHEF_VALIDATION_KEY' => join(['cred:PFT-LAMP-ChefValidator-',last(split(@@deployment.href,"/"))]),
    'CHEF_VALIDATION_NAME' => 'text:pft-validator',
    'CHEF_SSL_VERIFY_MODE' => 'text::verify_none',
    'DATABASE_HOST' => join(['env:DB-',last(split(@@deployment.href,"/")),':PRIVATE_IP']),
    'DATABASE_PASSWORD' => 'cred:CAT_MYSQL_APP_PASSWORD',
    'DATABASE_SCHEMA' => 'text:app_test',
    'DATABASE_USER' => 'cred:CAT_MYSQL_APP_USERNAME',
    'DELETE_NODE_ON_TERMINATE' => 'text:true',
    'ENABLE_AUTO_UPGRADE' => 'text:true',
    'LISTEN_PORT' => 'text:8080',
    'LOG_LEVEL' => 'text::info',
    'MANAGED_LOGIN' => 'text:auto',
    'MONITORING_METHOD' => 'text:auto',
    'REFRESH_TOKEN' => 'cred:PFT_RS_REFRESH_TOKEN',
    'SCM_REPOSITORY' => 'text:git://github.com/rightscale/examples.git',
    'SCM_REVISION' => 'text:unified_php',
    'UPGRADES_FILE_LOCATION' => 'text:https://rightlink.rightscale.com/rightlink/upgrades',
    'VHOST_PATH' => 'text:/'
  } end
  # Server Array Settings
  state "enabled"
  array_type "alert"
  elasticity_params do {
    "bounds" => {
      "min_count"            => 1,
      "max_count"            => 5 # Limited to 5 to avoid deploying too many servers.
    },
    "pacing" => {
      "resize_calm_time"     => 5,
      "resize_down_by"       => 1,
      "resize_up_by"         => 1
    },
    "alert_specific_params" => {
      "decision_threshold"   => 51,
      "voters_tag_predicate" => join(['App-',last(split(@@deployment.href,"/"))])
    }
  } end
end

## TO-DO: Set up separate security groups for each tier with rules that allow the applicable port(s) only from the IP of the given tier server(s)
resource "sec_group", type: "security_group" do
  name join(["sec_group-",last(split(@@deployment.href,"/"))])
  description "CAT security group."
  cloud map( $map_cloud, $param_location, "cloud" )
end

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

resource "sec_group_rule_http", type: "security_group_rule" do
  name "CAT HTTP Rule"
  description "Allow HTTP access."
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

resource "sec_group_rule_https", type: "security_group_rule" do
  name "CAT HTTPS Rule"
  description "Allow HTTPS access."
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

resource "sec_group_rule_http8080", type: "security_group_rule" do
  name "CAT HTTP Rule"
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

resource "sec_group_rule_mysql", type: "security_group_rule" do
  name "CAT MySQL Rule"
  description "Allow MySQL access over standard port."
  source_type "cidr_ips"
  security_group @sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "3306",
    "end_port" => "3306"
  } end
end


## In order for this CAT to compile, the parameters passed to map()
## must exist. When this package is consumed, the consuming CAT will
## redefine these

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

parameter "param_location" do
  like $parameters.param_location
end

parameter "param_chef_password" do
  like $lamp_parameters.param_chef_password
end
