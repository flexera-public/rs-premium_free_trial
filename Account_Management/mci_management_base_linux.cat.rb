# This CAT is used to create and manage the Linux MCI that PFT ServerTemplates reference and use.
# The intent is that this CAT is run in an account as part of its preparation for a PFT Trial.

# Basic Design:
# - Import the latest Ubuntu 14.04 MCI 
# - Check if there is an MCI named "PFT Base Linux MCI" already.
# - If not, create one.
# - Update the MCI to use the existent images found in the Ubuntu 14.04 MCI
# - Add the VMware image to the MCI
# - Update the pointer to use the latest 14.04 Trusty Google image.
#
# TO-DOs
# - The CAT takes several minutes to run. I think it's related to the looping through the settings collections and hitting the
#   .cloud() link/API call. Could probably do something where I do a single walk through the collections and build hashes.
#   But that would mess up some of the modularity in the mci_management.pkg.rb definitions.

name "PFT Admin CAT - PFT Base Linux MCI Setup/Maintenance"
rs_ca_ver 20160622
short_description "Used for PFT account administration.\n
This CAT is used to create/update/maintain the 'PFT Base Linux MCI' MCI used by other PFT assets."

import "pft/mci"

parameter "param_base_mci_name" do 
  category "Inputs"
  label "Name of MCI to use as a base" 
  type "string" 
  default "Ubuntu_14.04_x64"
end

parameter "param_base_google_image_name" do 
  category "Inputs"
  label "Name root for the image name in Google." 
  type "string" 
  default "ubuntu-1404-trusty-v"
end

# Currently not allowed to change this.
parameter "param_pft_mci_name" do 
  category "Inputs"
  label "Name of the created/maintained PFT MCI." 
  type "string" 
  default "PFT Base Linux MCI"
end

operation "launch" do
  description "Manage the MCI"
  definition "manage_mci"
end

define manage_mci($param_base_mci_name, $param_base_google_image_name, $param_pft_mci_name) do
  
  $base_linux_mci_name = $param_base_mci_name  # Name of the published MCI that we use at the base
  $pft_base_linux_mci_name = $param_pft_mci_name # Name of the MCI used by PFT assets.
  $google_image_name_root = $param_base_google_image_name # base name for Google Ubuntu image

  # regardless of what happens below we want to get the latest version of the Ubuntu MCI that we use as the base for updating or creating the PFT Base Linux MCI
  call mci.import_mci($base_linux_mci_name) retrieve @base_linux_mci
  
  if empty?(@base_linux_mci)
    raise "Could not find the starting base MCI, "+$base_linux_mci_name+" in the MultiCloud MarketPlace."
  end
  
  # Does the PFT Base Linux MCI already exist?
  call mci.find_mci($pft_base_linux_mci_name) retrieve @pft_base_mci
  
  # If PFT base linux MCI not found, create one based on the imported base linux MCI
  if empty?(@pft_base_mci)
    call create_pft_base_linux_mci($pft_base_linux_mci_name, @base_linux_mci) retrieve @pft_base_mci
  else # update the existing MCI with the standard MCI settings
    call mci.copy_mci_settings(@base_linux_mci, @pft_base_mci)
  end
  
  # At this point, we have a PFT Base Linux MCI that has the off-the-shelf settings.
  # So, now it's time update the VMware image if necessary.
  call update_vmware_image(@pft_base_mci)
  
  # And then update the Google image in case the off-the-shelf base linux MCI was pointing to a deprecated image.
  # (Google is very quick to deprecated images.)
  call update_google_image(@pft_base_mci, $google_image_name_root)  
  
end

# Create a new PFT Base Linux MCI of the given name
define create_pft_base_linux_mci($mci_name, @base_mci) return @mci do
  # Clone the MCI to use as the base for the PFT Linux MCI
  @base_mci.clone(multi_cloud_image: {name: $mci_name, description: $mci_name})
  
  # Find the MCI in the account
  call mci.find_mci($mci_name) retrieve @mci
  
  call get_vmware_cloud_elements() retrieve $vmware_cloud_href, $vmware_image_href, $vmware_instance_type_href
  @mci.settings().create(multi_cloud_image_setting: {cloud_href: $vmware_cloud_href, image_href: $vmware_image_href, instance_type_href: $vmware_instance_type_href})
end
 
define get_vmware_cloud_elements(@vmware_cloud) return $cloud_href, $image_href, $instance_type_href do
  # Need to add the VMware image to this newly created MCI.
  @image = @vmware_cloud.images(filter: ["name==PFT_Ubuntu_vmware"])
  @instance_type = @vmware_cloud.instance_types(filter: ["name==small"])
  
  $cloud_href = @vmware_cloud.href
  $image_href = @image.href
  $instance_type_href = @instance_type.href
end

define update_vmware_image(@mci) do
  @cloud = rs_cm.clouds.get(filter: ["name==VMware Private Cloud"])
  if (size(@cloud) > 0)
    # Get the vmware cloud related items
    call get_vmware_cloud_elements(@cloud) retrieve $vmware_cloud_href, $vmware_image_href, $vmware_instance_type_href
    call mci.mci_update_cloud_image(@mci, $vmware_cloud_href, $vmware_image_href)
  end
end

define update_google_image(@mci, $google_image_name_root) do
  # find the current google Ubuntu 14.04 image
  @cloud = rs_cm.clouds.get(filter: ["name==Google"])
    
  if (size(@cloud) > 0)
    @images = @cloud.images(filter: ["name=="+$google_image_name_root])  # partial match is all we need
    @image = last(@images)  # just grab one of them should be ok - may have to do some better regexp matching
    $cloud_href = @cloud.href
    $image_href = @image.href
  
    call mci.mci_update_cloud_image(@mci, $cloud_href, $image_href)
  end
end
