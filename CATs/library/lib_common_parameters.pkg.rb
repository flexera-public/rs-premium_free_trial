name "LIB - Common parameters"
rs_ca_ver 20160622
short_description "Parameters that are commonly used across multiple CATs"

package "pft/parameters"

parameter "param_location" do 
  category "Deployment Options"
  label "Cloud" 
  type "string" 
  allowed_values "AWS", "AzureRM", "Google", "VMware" 
  default "AWS"
end

parameter "param_numservers" do 
  category "Deployment Options"
  label "Number of Servers to Launch" 
  type "number" 
  min_value 1
  max_value 5
  constraint_description "Maximum of 5 servers allowed by this application."
  default 1
end

parameter "param_instancetype" do
  category "Deployment Options"
  label "Server Performance Level"
  type "list"
  allowed_values "Standard Performance",
    "High Performance"
  default "Standard Performance"
end

parameter "param_costcenter" do 
  category "Deployment Options"
  label "Cost Center" 
  type "string" 
  allowed_values "Development", "QA", "Production"
  default "Development"
end
