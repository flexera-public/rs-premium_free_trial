name "LIB - Common permissions"
rs_ca_ver 20161221
short_description "Permissions that should be declared to make the CAT has the permissions needed for calls to RS APIs."

package "pft/permissions"

# Pretty inclusive set of permissions.
# TODO: group things down into smaller sets perhaps so admin isn't always needed, etc.
permission "pft_general_permissions" do
  resources "rs_cm.tags", "rs_cm.instances", "rs_cm.audit_entries", "rs_cm.credentials", "rs_cm.clouds", "rs_cm.sessions", "rs_cm.accounts", "rs_cm.publications"
  actions   "rs_cm.*"
end

permission "pft_sensitive_views" do
  resources "rs_cm.credentials" # Currently these actions are not support for instance resources, "rs_cm.instances"
  actions "rs_cm.index_sensitive", "rs_cm.show_sensitive"
end