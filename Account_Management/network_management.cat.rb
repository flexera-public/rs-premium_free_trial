# This CAT is used to create a standard network in each of the AzureRM clouds for a given PFT account.
# The intent is that this CAT is run in an account as part of setting up a PFT account.
# It should only need to be run once when a PFT account is first created and possibly if new AzureRM clouds are attached and
# one wants to use the given ARM cloud.

# Basic Design:
# - Loop through the AzureRM clouds attached to the account.
# - If the cloud doesn't have a "pft_arm_network" set up for it, then create one and create a "default" subnet.
#

name "PFT Admin CAT - PFT Network Setup"
rs_ca_ver 20161221
short_description "Used for PFT account administration.\n
This CAT is used to create/add a network for any attached ARM clouds."

import "pft/err_utilities", as: "debug"

### Network Definitions ###
resource "base_network", type: "network" do
  name "pft_arm_network"
  cloud "AzureRM East US"
  cidr_block "172.16.1.0/24"
end

resource "base_subnet", type: "subnet" do
  name "default"
  cloud "AzureRM East US"
  cidr_block "172.16.1.0/24"
  network @base_network
end

operation "launch" do
  description "Setup Networks"
  definition "setup_networks"
end

operation "auto_terminate" do
  description "Don't delete the last network which was created"
  definition "nil_auto_terminate"
end

define nil_auto_terminate(@base_network, @base_subnet) return @base_network, @base_subnet do

end

define setup_networks(@base_network, @base_subnet) do

  # Use this as the base for provisioning the networks in each cloud
  $base_network_hash = to_object(@base_network)
  $base_subnet_hash = to_object(@base_subnet)
  $base_subnet_hash["dependencies"] = []
  $base_subnet_hash["unresolved_fields"] = []

  # build an array of the cloud_hrefs for any existing networks of the given name.
  @current_pft_arm_networks = rs_cm.networks.get(filter: ["name==pft_arm_network"])
  if size(@current_pft_arm_networks) == 0
    $current_pft_arm_network_cloud_hrefs = []
  else
    $current_pft_arm_network_cloud_hrefs = @current_pft_arm_networks.cloud().href[]
  end
  
  # Find the clouds attached to the account
  @arm_clouds = rs_cm.clouds.get(filter: ["cloud_type==azure_v2"])
    
  call debug.log("NETWORK SETUP: Found "+size(@current_pft_arm_networks)+" existing PFT networks; Found "+size(@arm_clouds)+" attached ARM clouds", "")
#  call debug.log("EXISTING NETWORKS", to_s($current_pft_arm_network_cloud_hrefs))
#  call debug.log("EXISTING ARM CLOUDS", to_s(to_object(@arm_clouds)))
    
  concurrent foreach @arm_cloud in @arm_clouds do
    $arm_cloud_href = @arm_cloud.href
    if logic_not(contains?($current_pft_arm_network_cloud_hrefs, [$arm_cloud_href]))
      $new_network = $base_network_hash
      $new_network["fields"]["cloud_href"] = $arm_cloud_href
      $new_network["fields"]["deployment_href"] = null
      @new_network = $new_network
      call debug.log("NETWORK SETUP: Provisioning pft_arm_network in cloud: "+@arm_cloud.name+", href: "+$arm_cloud_href, to_s(to_object(@new_network)))
      provision(@new_network)
      
      $new_network_href = @new_network.href
      
      $default_subnet = $base_subnet_hash
      $default_subnet["fields"]["cloud_href"] = $arm_cloud_href
      $default_subnet["fields"]["network_href"] = $new_network_href
      $default_subnet["fields"]["deployment_href"] = null
      @default_subnet = $default_subnet
      call debug.log("NETWORK SETUP: Provisioning default subnet in network: "+$new_network_href, to_s(to_object(@default_subnet)))
  
      # Sometimes the network is not yet presented by AzureRM and so the provision of the subnet fails.
      # If it does, wait a bit and try again.
      sub on_error: wait_and_retry($arm_cloud_href) do
        provision(@default_subnet)
      end

    end
  end
end

define wait_and_retry($item) do
  call debug.log("RETRYING provision of subnet in cloud: "+$item, "")
  sleep(5)
  $_error_behavior = "retry"
end


