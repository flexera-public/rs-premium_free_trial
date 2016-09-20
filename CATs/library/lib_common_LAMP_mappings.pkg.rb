name "LIB - Common LAMP mappings"
rs_ca_ver 20160622
short_description "Mappings that are commonly used for LAMP stack CATs"

package "common/lamp_mappings"

# Mapping of which ServerTemplates and Revisions to use for each tier.
mapping "map_st" do {
  "lb" => {
    "name" => "Load Balancer with HAProxy (v14.1.1)",
    "rev" => "43",
  },
  "app" => {
    "name" => "PHP App Server (v14.1.1)",
    "rev" => "44",
  },
  "db" => {
    "name" => "Database Manager for MySQL (v14.1.1)",
    "rev" => "56",
  }
} end

mapping "map_mci" do {
  "VMware" => { # vSphere 
    "mci_name" => "RightImage_CentOS_6.6_x64_v14.2_VMware",
    "mci_rev" => "9",
  },
  "Public" => { # all other clouds
    "mci_name" => "RightImage_CentOS_6.6_x64_v14.2",
    "mci_rev" => "24",
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