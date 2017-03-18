name "S-1) PHP Production Stack (Stub)"
rs_ca_ver 20131202
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/php.png) 

Launch a PHP Production environment that includes HA and Disaster Recovery"

output "output_stubcat" do
  label "Note to User"
  default_value "This is a stub Cloud Application Template.\nIt does not launch any servers."
end

operation "launch" do
  description "Stub CAT Operation"
  definition "definition_stubcat"
end

define definition_stubcat() do
  # do nothing
end