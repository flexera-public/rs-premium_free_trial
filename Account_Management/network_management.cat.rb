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

define setup_networks(@base_network) do
  
  # Use this as the base for provisioning the networks in each cloud
  $base_network_hash = to_object(@base_network)
  
  # build an array of the cloud_hrefs for any existing networks of the given name.
  @current_pft_arm_networks = rs_cm.networks.get(filter: ["name==pft_arm_network"])
  $current_pft_arm_network_cloud_hrefs = @current_pft_arm_networks.cloud().href[]
      
  # Find the clouds attached to the account
  @arm_clouds = rs_cm.clouds.get(filter: ["name==AzureRM"])
    
  foreach @arm_cloud in @arm_clouds do
    $arm_cloud_href = @arm_cloud.href
    if logic_not(contains?($current_pft_arm_network_cloud_hrefs, [$arm_cloud_href]))
      $new_network = $base_network_hash
      $new_network["fields"]["cloud_href"] = $arm_cloud_href
      @new_network = $new_network
      provision(@new_network)
    end
  end
end
