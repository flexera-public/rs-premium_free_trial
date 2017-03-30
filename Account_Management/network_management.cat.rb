# This CAT is used to create a standard network in each of the AzureRM clouds for a given PFT account.
# The intent is that this CAT is run in an account as part of setting up a PFT account.
# It should only need to be run once when a PFT account is first created and possibly if new AzureRM clouds are attached and
# one wants to use the given ARM cloud.

# Basic Design:
# - Loop through the AzureRM clouds attached to the account.
# - If the cloud doesn't have a "pft_arm_network" set up for it, then create one.
#

name "PFT Admin CAT - PFT Network Setup"
rs_ca_ver 20160622
short_description "Used for PFT account administration.\n
This CAT is used to create/add a network for any attached ARM clouds."

import "pft/err_utilities", as: "debug"

### Network Definitions ###
resource "base_network", type: "network" do
  name "pft_arm_network"
  cloud "AzureRM East US"
  cidr_block "172.16.1.0/24"
end

operation "launch" do
  description "Setup Networks"
  definition "setup_networks"
end

operation "auto_terminate" do
  description "Don't delete the last network which was created"
  definition "nil_auto_terminate"
end

define nil_auto_terminate(@base_network) return @base_network do

end

define setup_networks(@base_network) do

  # Use this as the base for provisioning the networks in each cloud
  $base_network_hash = to_object(@base_network)

  # build an array of the cloud_hrefs for any existing networks of the given name.
  @current_pft_arm_networks = rs_cm.networks.get(filter: ["name==pft_arm_network"])
  if size(@current_pft_arm_networks) == 0
    $current_pft_arm_network_cloud_hrefs = []
  else
    $current_pft_arm_network_cloud_hrefs = @current_pft_arm_networks.cloud().href[]
  end

  # Find the clouds attached to the account
  @arm_clouds = rs_cm.clouds.get(filter: ["cloud_type==azure_v2"])
    
  #call debug.log("NETWORK SETUP: Found "+size(@current_pft_arm_networks)+" existing PFT networks; Found "+size(@arm_clouds)+" attached ARM clouds", "")

  concurrent foreach @arm_cloud in @arm_clouds do
    $arm_cloud_href = @arm_cloud.href
    if logic_not(contains?($current_pft_arm_network_cloud_hrefs, [$arm_cloud_href]))
      $new_network = $base_network_hash
      $new_network["fields"]["cloud_href"] = $arm_cloud_href
      $new_network["fields"]["deployment_href"] = null
      @new_network = $new_network
      call debug.log("NETWORK SETUP: Provisioning pft_arm_network in cloud: "+$arm_cloud_href, to_s(to_object(@new_network)))
      provision(@new_network)
    end
  end
end


