# This package provides various MCI-related functions

name "LIB - MCI Management"
rs_ca_ver 20160622
short_description "Utilties related to MCI management."

package "pft/mci"
import "pft/mci/linux_mappings", as: "linux_mappings"
import "pft/err_utilities", as: "debug"


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

# Uses the MCI info map to see if there is already an MCI of the given name in the account.
# If not, it creates one of the given name.
# It then updates the images pointed to by the MCI by finding the applicable image as per the Image Name mapping and the
# Cloud mapping.
define mci_setup($os, $map_mci_info, $map_image_name_root, $map_cloud) return @mci do
  
  # Name of the custom MCI we are creating/updating
  $mci_name = map($map_mci_info, $os, "custom_mci_name")
  call debug.log("mci_setup - working on custom MCI, "+$mci_name, "")

  # Check if the MCI already exists
  call find_mci($mci_name) retrieve @mci
  if empty?(@mci)
    # Import a starting MCI. 
    # It's good to start with an imported MCI since then we're sure any 
    # required tags and stuff are set correctly.
    $base_mci_name = map($map_mci_info, $os, "base_mci_name")
    call import_mci($base_mci_name) retrieve @base_mci
    if empty?(@base_mci)
      raise "Could not find the starting base MCI, "+$base_mci_name+" in the MultiCloud MarketPlace."
    end
    @base_mci.clone(multi_cloud_image: {name: $mci_name, description: $mci_name})
 
    # Find the newly created MCI so as to set @mci for subsequent use
    call find_mci($mci_name) retrieve @mci
  end
  
  # At this point, we have an MCI that was created or already existed.
  # Now it's time to have it point to the latest images in the required clouds.
  foreach $cloud in keys($map_cloud) do
    
    # Only bother to process a cloud for which we have image name in the mapping
    if map($map_image_name_root, $os, $cloud)
    
      # Get cloud resource
      $cloud_name = map($map_cloud, $cloud, "cloud")
      @cloud = find("clouds", $cloud_name)
      
      call debug.log("mci_setup - Cloud name: "+$cloud_name+", cloud href: "+to_s(@cloud.href), "")
      
      # Make sure the cloud is attached to the account. If not don't worry about it.
      if (size(@cloud) > 0)
        $cloud_href = @cloud.href
        call find_image_href(@cloud, $map_image_name_root, $os, $cloud) retrieve $image_href
        call mci_upsert_cloud_image(@mci, $cloud_href, $image_href)
      end
    end
  end
end

define find_image_href(@cloud, $map_image_name_root, $mci, $cloud) return $image_href do
#  call debug.log("find_image_href inputs", to_s(@cloud)+"; "+$mci_name+"; "+$cloud_name)

  # set up search parameters
  $base_image_name_with_regexp_extension = map($map_image_name_root, $mci, $cloud)
  $base_image_name = gsub($base_image_name_with_regexp_extension, /<<.*>>/, "")
  $regexp_extension = gsub($base_image_name_with_regexp_extension, $base_image_name, "")
  $regexp_extension = gsub($regexp_extension, "<<", "")
  $regexp_extension = gsub($regexp_extension, ">>", "")
 
  # Find images that match the given base name.
  @images = @cloud.images(filter: ["name=="+$base_image_name])  # partial match
  #call debug.log("mci_setup - Found "+size(@images)+" images with base name of, "+$base_image_name, "")
  
  # Filter these results using any provided trailing regular expression
  # forward slashes don't play well with the select function, so substitute them with dots.
  $base_image_selector = "/^"+gsub($base_image_name+$regexp_extension, "/", ".")+"$/"
  
  @image = last(select(@images, { "name": $base_image_selector }))
             
  $image_href = @image.href
  
  call debug.log("Found image, "+to_s(@image.name)+", href, "+to_s($image_href)+", using regexp, "+$base_image_selector, to_s(@image))
end

# Some clouds don't support a "latest" designation for images.
# In those clouds, it's useful to check if the MCI is pointing at a deprecated image and fix things if so.
# This adds about a minute to the launch but is worth it to avoid a failure due to the cloud provider
# deprecating the image we use.
define updateImage($cloud_name, $param_location, $mci_name) do
  if $param_location == "AWS"
    $mci_name = map($map_config, "mci", "name")
    call find_mci($mci_name) retrieve @mci
    @cloud = find("clouds", $cloud_name)
    call find_image_href(@cloud, $map_image_name_root, $mci_name, $param_location) retrieve $image_href
    call mci_upsert_cloud_image(@mci, @cloud.href, $image_href)
  end
end


# Update an MCI to point to a new image for a given cloud, or add an image to
# for a cloud which was not previously supported.
define mci_upsert_cloud_image(@mci, $cloud_href, $image_href) do
  #call debug.log("mci_upsert_cloud_image - cloud_href: " + to_s($cloud_href) + ", image_href: "+ to_s($image_href), "")
  $updated = false
  # update the MCI setting to point to a given cloud image.
  @mci_settings = @mci.settings()
  foreach @setting in @mci_settings do
    sub on_error: skip do  # There may be cloud() links in the collection that are undefined in the account.
      if @setting.cloud().href == $cloud_href
        #call debug.log("mci_upsert_cloud_image - updating existing cloud image reference in MCI", "")
        @setting.update(multi_cloud_image_setting: {image_href: $image_href})
        $updated = true
      end
    end
  end

  # Insert usecase
  @mci_setting = @mci.settings(filter: ["cloud_href=="+$cloud_href])
  call debug.log("mci_upsert_cloud- mci: " + to_s(@mci.href) + ", mci_setting: ", to_s(@mci_setting))
  if (size(@mci_setting) == 0)
    #call debug.log("mci_upsert_cloud_image - adding cloud image reference to MCI", "")
    @cloud = rs_cm.get(href: $cloud_href)

    @instance_types = @cloud.instance_types()
    @instance_type = first(@instance_types) 
    sub on_error: skip do  # Multiple attempts at adding the same setting are ignored
      @mci_settings.create(multi_cloud_image_setting: {image_href: $image_href, cloud_href: $cloud_href, instance_type_href: @instance_type.href})
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

########
mapping "map_image_name_root" do 
 like $linux_mappings.map_image_name_root
end
