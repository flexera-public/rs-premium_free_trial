# This CAT is used to create and manage the Linux MCI that PFT ServerTemplates reference and use.
# The intent is that this CAT is run in an account as part of its preparation for a PFT Trial.

# Basic Design:
# - Import the latest Ubuntu 14.04 MCI 
# - Check if there is an MCI named "PFT Base Linux MCI" already.
# - If not, create one.
# - Update the MCI to use the existent images found in the Ubuntu 14.04 MCI
# - Add the VMware image to the MCI
# - Update the pointer to use the latest 14.04 Trusty Google image.

name "Account Admin CAT - PFT Base Linux MCI Setup/Maintenance"
rs_ca_ver 20160622
short_description "Used for PFT account administration. This CAT is used to create/update/maintain the 'PFT Base Linux MCI' MCI used by other PFT assets."

#parameter "param_mci_name" do
#  category "Inputs"
#  label "MCI Name" 
#  type "string" 
#  #allowed_values ""
#  default "PFT Base Linux MCI"
#end

operation "launch" do
  description "Manage the MCI"
  definition "manage_mci"
end


define manage_mci() do
  
  $base_linux_mci_name = "Ubuntu_14.04_x64"  # Name of the published MCI that we use at the base
  $pft_base_linux_mci_name = "PFT Base Linux MCI" # Name of the MCI used by PFT assets.

  # regardless of what happens below we want to get the latest version of the Ubuntu MCI that we use as the base for updating or creating the PFT Base Linux MCI
  call import_mci($base_linux_mci_name) retrieve @base_linux_mci
  
  if empty?(@base_linux_mci)
    raise "Could not find the starting base MCI, "+$base_linux_mci_name+" in the MultiCloud MarketPlace."
  end
  
  # Does the PFT Base Linux MCI already exist?
  call find_mci($pft_base_linux_mci_name) retrieve @pft_base_mci
  
  # If PFT base linux MCI not found, create one based on the imported base linux MCI
  if empty?(@pft_base_mci)
    call create_pft_base_linux_mci($pft_base_linux_mci_name, @base_linux_mci) retrieve @pft_base_mci
  else # update the existing MCI with the standard MCI settings
    call copy_mci_settings(@base_linux_mci, @pft_base_mci)
  end
  
  # At this point, we have a PFT Base Linux MCI that has the off-the-shelf settings.
  # So, now it's time update the VMware image if necessary.
  call update_vmware_image(@pft_base_mci)
  
  # And then update the Google image in case the off-the-shelf base linux MCI was pointing to a deprecated image.
  # (Google is very quick to deprecated images.)
  call update_google_image(@pft_base_mci)  
  
end

# Find an MCI in the account that exactly matches the given MCI name
define find_mci($mci_name) return @desired_mci do
  # mci index is a partial match so it is possible more than one MCI will be returned
  @mcis = rs_cm.multi_cloud_images.get(filter: ["name=="+$mci_name])
  foreach @mci in @mcis do
    if @mci.name == $mci_name
      @desired_mci = @mci
    end
  end
end

# Import a given MCI from the MultiCloud MarketPlace and return the imported item.
define import_mci($pub_name) return @imported_item do
  @pubs = rs_cm.publications.index(filter: ["name=="+$pub_name])
  foreach @pub in @pubs do
   if @pub.name == $pub_name
     @pub.import
   end
  end
  call find_mci($pub_name) retrieve @imported_item
end

# Create a new PFT Base Linux MCI of the given name
define create_pft_base_linux_mci($mci_name, @base_mci) return @mci do
  # Clone the MCI to use as the base for the PFT Linux MCI
  @base_mci.clone(multi_cloud_image: {name: $mci_name, description: $mci_name})
  
  # Find the MCI in the account
  call find_mci($mci_name) retrieve @mci
  
  call get_vmware_cloud_elements() retrieve $vmware_cloud_href, $vmware_image_href, $vmware_instance_type_href
  @mci.settings().create(multi_cloud_image_setting: {cloud_href: $vmware_cloud_href, image_href: $vmware_image_href, instance_type_href: $vmware_instance_type_href})
end
 
define get_vmware_cloud_elements() return $cloud_href, $image_href, $instance_type_href do
  # Need to add the VMware image to this newly created MCI.
  @cloud = rs_cm.clouds.get(filter: ["name==VMware Private Cloud"])
  @image = @cloud.images(filter: ["name==PFT_Ubuntu_vmware"])
  @instance_type = @cloud.instance_types(filter: ["name==small"])
  
  $cloud_href = @cloud.href
  $image_href = @image.href
  $instance_type_href = @instance_type.href
end

define update_vmware_image(@mci) do
  # Get the vmware cloud related items
  call get_vmware_cloud_elements() retrieve $vmware_cloud_href, $vmware_image_href, $vmware_instance_type_href
  call update_mci_setting(@mci, $vmware_cloud_href, $vmware_image_href)
end

define update_google_image(@mci) do
  # find the current google Ubuntu 14.04 image
  @cloud = rs_cm.clouds.get(filter: ["name==Google"])
  @images = @cloud.images(filter: ["name==ubuntu-1404-trusty-v"])  # partial match is all we need
  @image = last(@images)  # just grab one of them should be ok - may have to do some better regexp matching
  $cloud_href = @cloud.href
  $image_href = @image.href
  
  call update_mci_setting(@mci, $cloud_href, $image_href)
end

define update_mci_setting(@mci, $cloud_href, $image_href) do
  # update the MCI setting for google to point to the given image if different
  # Find the vmware setting in the mci and update if needed
  @mci_settings = @mci.settings()
  foreach @setting in @mci_settings do
    sub on_error: skip do
      if @setting.cloud().href == $cloud_href
        @setting.update(multi_cloud_image_setting: {image_href: $image_href})
      end
    end
  end
end

# Update a given MCI with the settings from another MCI
define copy_mci_settings(@source_mci, @target_mci) do
  
  # Get the settings for the source mci
  @source_mci_settings = @source_mci.settings()
  # Create a hash to get quick access to the image href based on the cloud href
  $source_href_hash = {}
  foreach @setting in @source_mci_settings do
    sub on_error: skip do
      $source_href_hash[@setting.cloud().href] = @setting.image().href
    end
  end
  
  # Get the settings in the target_mci
  @target_mci_settings = @target_mci.settings()
  foreach @target_setting in @target_mci_settings do
    sub on_error: skip do
      @target_setting.update(multi_cloud_image_setting: {image_href: $source_href_hash[@target_setting.cloud().href]})
    end
  end
end


# Build an array of attached clouds
define unused_get_attached_clouds() return $attached_cloud_array do
  $attached_cloud_array = []
  @clouds = rs_cm.clouds.get()
  foreach @cloud in @clouds do
    $attached_cloud_array << @cloud.href
  end
end