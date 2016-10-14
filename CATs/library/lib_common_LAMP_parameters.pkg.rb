name "LIB - Common LAMP parameters"
rs_ca_ver 20160622
short_description "Parameters that are commonly used in LAMP CATs"

package "pft/lamp_parameters"

parameter "param_appcode" do 
  category "Application Code"
  label "Repository and Branch" 
  type "string" 
  allowed_values "(Yellow) github.com/rightscale/examples:unified_php", "(Blue) github.com/rs-services/rs-premium_free_trial:unified_php_modified" 
  default "(Blue) github.com/rs-services/rs-premium_free_trial:unified_php_modified"
end
