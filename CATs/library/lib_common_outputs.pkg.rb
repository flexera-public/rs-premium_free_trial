name "LIB - Common outputs"
rs_ca_ver 20160622
short_description "Outputs that are commonly used across multiple CATs"

package "pft/outputs"
import "pft/conditions"

output "vmware_note" do
  condition $invSphere
  label "Deployment Note"
  category "Output"
  default_value "Your CloudApp was deployed in a VMware environment on a private network and so is not directly accessible. If you need access to the CloudApp, please contact your RightScale rep for network access."
end

condition "invSphere" do
  like $conditions.invSphere
end