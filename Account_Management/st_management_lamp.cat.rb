# This CAT is used to import the prerequisites for the ServerTemplates used by the LAMP CAT.

name "PFT Admin CAT - PFT LAMP ServerTemplates Prerequisite Import"
rs_ca_ver 20160622
short_description "Used for PFT account administration.\n
This CAT is used to import the prerequisites for the ServerTemplates used by the LAMP CAT."

import "pft/server_templates_utilities", as: "st"

mapping "map_st" do {
  "db" => {
    "name" => "Database Manager for MySQL for Chef Server (RightLink 10)",
    "rev" => "14"
  },
  "php" => {
    "name" => "PHP Application Server for Chef Server (RightLink 10)",
    "rev" => "15"
  },
  "haproxy" => {
    "name" => "Load Balancer with HAProxy for Chef Server (RightLink 10)",
    "rev" => "15"
  }
}
end

operation "launch" do
  description "Manage the STs"
  definition "manage_st"
end

define manage_st($map_st) do
  call st.importServerTemplate($map_st)
end
