name "S-5) MySQL Database (Stub)"
rs_ca_ver 20131202
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/mysql.png) 

Launch an HA ready MySQL database on Amazon, Azure and VMware"

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