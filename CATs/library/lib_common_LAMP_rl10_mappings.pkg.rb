name "LIB - Common LAMP mappings RL10"
rs_ca_ver 20160622
short_description "Mappings that are commonly used for LAMP stack CATs"

package "pft/rl10/lamp_mappings"

# Mapping of which ServerTemplates and Revisions to use for each tier.
mapping "map_st" do {
  "chef" => {
    "name" => "PFT Chef Server for Linux (RightLink 10)",
    "rev" => "0",
  },
  "lb" => {
    "name" => "PFT Load Balancer with HAProxy for Chef Server (RightLink 10)",
    "rev" => "0",
  },
  "app" => {
    "name" => "PFT PHP Application Server for Chef Server (RightLink 10)",
    "rev" => "0",
  },
  "db" => {
    "name" => "PFT Database Manager for MySQL for Chef Server (RightLink 10)",
    "rev" => "0",
  }
} end

mapping "map_mci" do {
  "VMware" => { # vSphere
    "mci_name" => "PFT Base Linux MCI",
    "mci_rev" => "0",
  },
  "Public" => { # all other clouds
    "mci_name" => "PFT Base Linux MCI",
    "mci_rev" => "0",
  }
} end

# Mapping of names of the creds to use for the DB-related credential items.
# Allows for easier maintenance down the road if needed.
mapping "map_db_creds" do {
  "root_password" => {
    "name" => "CAT_MYSQL_ROOT_PASSWORD",
  },
  "app_username" => {
    "name" => "CAT_MYSQL_APP_USERNAME",
  },
  "app_password" => {
    "name" => "CAT_MYSQL_APP_PASSWORD",
  }
} end
