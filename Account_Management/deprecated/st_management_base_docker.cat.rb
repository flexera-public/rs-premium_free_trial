# This CAT is used to create and manage a PFT Base Linux ServerTemplate
# The intent is that this CAT is run in an account when an updated RL10 Base Linux ServerTemplate is available.

# Basic Design:
# - Delete the existing "PFT Base Linux ServerTemplate"
# - Import the latest RL10.x.x Linux ServerTemplate
# - Clone it as "PFT Base Linux ServerTemplate"
# - Modify the new ST to point at the "PFT Base Linux MCI" MCI.

name "PFT Admin CAT - PFT Base Docker ServerTemplate Setup/Maintenance"
rs_ca_ver 20161221
short_description "Used for PFT account administration.\n
This CAT is used to create/update/maintain the PFT Base Docker ServerTemplate."

import "pft/server_templates_utilities", as: "st"
import "pft/mci"

parameter "param_starting_st" do 
  category "Inputs"
  label "Name of RL10 Base Docker ServerTemplate" 
  type "string" 
  default "Docker Node"
end

operation "launch" do
  description "Manage the ST"
  definition "manage_st"
end

define manage_st($param_starting_st) do
  
  $pft_base_docker_st_name = "PFT Base Docker" # Name of the Docker ST used by PFT assets.
  
  # Get the latest revision of the official ServerTemplate
  @marketplace_st = last(rs_cm.publications.index(filter: ["name=="+$param_starting_st]))
  if empty?(@marketplace_st)
    raise "Cloud not find ServerTemplate, "+$param_starting_st+" in the MultiCloud MarketPlace."
  end
  
  # Check that the official PFT Base Linux MCI is available in the account
  $base_mci = "PFT Base Linux MCI"
  call mci.find_mci($base_mci) retrieve @pft_base_linux_mci
  if empty?(@pft_base_linux_mci)
    raise "Could not find MCI, "+$base_mci+" MCI in the Account."
  end
  
  # If RL10 published ST is found, import it and then find it in the account
  @marketplace_st.import()
  call st.find_st($param_starting_st) retrieve @marketplace_st
  
  # Is there already a PFT Base Linux ST in the account?
  call st.find_st($pft_base_docker_st_name) retrieve @pft_base_docker_st
  
  # If so, delete it so we can create a fresh on using the latest published RL10 ST
  if logic_not(empty?(@pft_base_docker_st))
    @pft_base_docker_st.destroy()
  end
  
  # Create a new ST based on the published ST
  @marketplace_st.clone(server_template: {name: $pft_base_docker_st_name, description: $pft_base_docker_st_name})
  # Find the newly created ST
  call st.find_st($pft_base_docker_st_name) retrieve @pft_base_docker_st
  
  # Add the PFT Base Linux MCI as the default MCI to this newly created ST
  @st_mci = rs_cm.server_template_multi_cloud_images.create(server_template_multi_cloud_image: {multi_cloud_image_href: @pft_base_linux_mci.href, server_template_href: @pft_base_docker_st.href})
  @st_mci.make_default()
  
end