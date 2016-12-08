# This CAT is used to create and manage the Linux MCI that PFT ServerTemplates reference and use.
# The intent is that this CAT is run in an account as part of its preparation for a PFT Trial.

# Basic Design:
# - Check if there is an MCI named "PFT Base Linux MCI" already.
# - If not, create one.
# - Import the latest Ubuntu 14.04 MCI used by the latest RL10 ST
# - Update the MCI to use the existent images found in the Ubuntu 14.04 MCI
# - Add the VMware image to the MCI
# - Check if the google image is still valid and update that if needed

name "Account Admin CAT - Set up PFT Base Linux MCI"
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


define manage_mci($param_mci_name) do
  
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
  if empty?(@mci)
    call create_pft_base_linux_mci($param_mci_name, @base_linux_mci) retrieve @pft_base_mci
  else # update the existing MCI with the standard MCI settings
    call copy_mci_settings(@base_linux_mci, @pft_base_mci)
  end
  
  # At this point, we have a PFT Base Linux MCI that has the off-the-shelf settings.
  # So, now it's time to add the VMware image.
  
  # And then update the Google image in case the off-the-shelf base linux MCI was pointing to a deprecated image.
  # (Google is very quick to deprecated images.)
  
  # The base set will come from the latest base Ubuntu MCI that is out there in the marketplace
  
  
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
  
  call find_mci($mci_name) retrieve @mci
end

# Update a given MCI with the settings from another MCI
define copy_mci_settings(@source_mci, @target_mci) do
  
  # Get the settings in the target_mci
  @target_mci_settings = @target_mci.settings()
  
  # Get the settings for the source mci
  @source_mci_settings = @source_mci.settings()
  
  foreach @target_setting in @target_mci_settings do
    $target_setting_hash = to_object(@target_setting)
    $target_setting_hash[]
  end
  
  @source_settings = @mci_source.settings()
      
 # call log("#########", to_s(to_object(@source_settings)))

  foreach @setting in @source_settings do
    call log("cloud: "+to_s(@setting.cloud().href), "")
    call log("image: "+ to_s(@setting.image().href), "")
    call log("instance_type: "+to_s(@setting.instance_type().href), "")
    
    
    
    
  
end