name "LIB - Common conditions"
rs_ca_ver 20160622
short_description "Conditions that are commonly used across multiple CATs"

package "pft/conditions"
import "pft/parameters"

condition "needsSshKey" do
  logic_or(equals?($param_location, "AWS"), equals?($param_location, "VMware"))
end

condition "needsSecurityGroup" do
  logic_or(equals?($param_location, "AWS"), equals?($param_location, "Google"))
end

condition "needsPlacementGroup" do
  equals?($param_location, "Azure")
end

condition "invSphere" do
  equals?($param_location, "VMware")
end

condition "inAzure" do
  equals?($param_location, "Azure")
end

## needed for compilation
parameter "param_location" do
  like $parameters.param_location
end