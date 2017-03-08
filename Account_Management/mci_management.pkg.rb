# This package provides various MCI-related functions

name "LIB - MCI Management"
rs_ca_ver 20160622
short_description "Utilties related to MCI management."

package "pft/mci"


# Find an MCI in the account that EXACTLY matches the given MCI name.
# The API is a partial match API. This function only returns something if it matches exactly.
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
     @pub.import()
   end
  end
  call find_mci($pub_name) retrieve @imported_item
end

# Update an MCI to point to a new image for a given cloud, or add an image to
# for a cloud which was not previously supported.
define mci_upsert_cloud_image(@mci, $cloud_href, $image_href) do
  $updated = false
  # update the MCI setting to point to a given cloud image.
  @mci_settings = @mci.settings()
  foreach @setting in @mci_settings do
    sub on_error: skip do  # There may be cloud() links in the collection that are undefined in the account.
      if @setting.cloud().href == $cloud_href
        @setting.update(multi_cloud_image_setting: {image_href: $image_href})
        $updated = true
      end
    end
  end

  # Insert usecase
  if !$updated
    @cloud = rs_cm.get(href: $cloud_href)

    @instance_types = @cloud.instance_types()
    @instance_type = last(@instance_types)
    @mci_settings.create(multi_cloud_image_setting: {image_href: $image_href, cloud_href: $cloud_href, instance_type_href: @instance_type.href})
  end
end

# Update a given MCI with the settings from another MCI
define copy_mci_settings(@source_mci, @target_mci) do

  # Get the settings for the source mci
  @source_mci_settings = @source_mci.settings()
  # Create a hash to get quick access to the image href based on the cloud href
  $source_href_hash = {}
  foreach @setting in @source_mci_settings do
    sub on_error: skip do # There may be cloud() links in the collection that are undefined in the account.
      $source_href_hash[@setting.cloud().href] = @setting.image().href
    end
  end

  # Get the settings in the target_mci
  @target_mci_settings = @target_mci.settings()
  foreach @target_setting in @target_mci_settings do
    sub on_error: skip do # There may be cloud() links in the collection that are undefined in the account.
      @target_setting.update(multi_cloud_image_setting: {image_href: $source_href_hash[@target_setting.cloud().href]})
    end
  end
end
