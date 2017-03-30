# This CAT is used to create and manage the Linux MCI that PFT ServerTemplates reference and use.
# The intent is that this CAT is run in an account as part of its preparation for a PFT Trial.

# Basic Design:
# - Import the applicable Linux MCIs
# - Check if a PFT Base Linux MCI already exixsts.
# - If not, create one.
# - Update the MCI to use the latest images across the connected clouds.
#
# TO-DOs
# - The CAT takes several minutes to run. I think it's related to the looping through the settings collections and hitting the
#   .cloud() link/API call. Could probably do something where I do a single walk through the collections and build hashes.
#   But that would mess up some of the modularity in the mci_management.pkg.rb definitions.

name "PFT Admin CAT - PFT Base Linux MCI Setup/Maintenance"
rs_ca_ver 20160622
short_description "Used for PFT account administration.\n
This CAT is used to create/update/maintain the PFT Base Linux MCI(s) used by other PFT assets."

import "pft/mappings"
import "pft/mci"
import "pft/mci/linux_mappings", as: "linux_mappings"

# mappings of starting MCI to clone from
mapping "map_mci_info" do 
  like $linux_mappings.map_mci_info
end

# Mappings of image name for each of the support clouds.
# A rudimentary regexp capability is supported to help narrow down the image to use.
# The assumption is that the given image name root is searched with leading and trailing anchors: /^STRING$/.
# However, you can add a trailing regexp, in square brackets [ ], to handle cases where the name changes over time.
# Note the need to escape any backslashes.
mapping "map_image_name_root" do 
 like $linux_mappings.map_image_name_root
end

mapping "map_cloud" do 
  like $mappings.map_cloud
end

operation "launch" do
  description "Manage the MCI"
  definition "manage_mci"
end

define manage_mci($map_mci_info, $map_image_name_root, $map_cloud) do

  $resource_array = []
  $mci_types = [ "PFT Base Linux", "PFT Ubuntu 16.04" ] # should match the keys into the $map_mci_info and $map_image_name_root maps
  foreach $mci_type in $mci_types do
    call mci.mci_setup($mci_type, $map_mci_info, $map_image_name_root, $map_cloud) retrieve @mci
    $resource_array << @mci.href
  end

  # Make sure the install-at-boot tags are set up on the MCI
  rs_cm.tags.multi_add(resource_hrefs: $resource_array, tags: ["rs_agent:mime_shellscript=https://rightlink.rightscale.com/rll/10/rightlink.boot.sh", "rs_agent:type=right_link_lite"])
  
end
