# This CAT is used to create and manage a PFT Base Windows ServerTemplate
# The intent is that this CAT is run in an account when prepping for a prospect so as to make sure there are
# current ServerTemplates and related images being used.
#
# Basic Design:
# - Delete the existing "PFT Base Windows ServerTemplate"
# - Import the latest RL10.x.x Windows ServerTemplate
# - Clone it as "PFT Base Windows ServerTemplate"
# - Modify the new ST to point at the PFT Windows MCIs.

name "PFT Admin CAT - PFT Base Windows ServerTemplate Setup/Maintenance"
rs_ca_ver 20161221
short_description "Used for PFT account administration.\n
This CAT is used to create/update/maintain the PFT Base Windows ServerTemplate ServerTemplate."

import "pft/server_templates_utilities", as: "st"
import "pft/mci"
import "pft/mci/windows_mappings"


parameter "param_starting_st" do 
  category "Inputs"
  label "Name of RL10 Base Windows ServerTemplate" 
  type "string" 
  default "RightLink 10.6.0 Windows Base"
end

mapping "map_mci_info" do 
  like $windows_mappings.map_mci_info
end

operation "launch" do
  description "Manage the ST"
  definition "manage_st"
end

define manage_st($param_starting_st, $map_mci_info) do
  
  $pft_base_st_name = "PFT Base Windows ServerTemplate" # Name of the MCI used by PFT assets.
  
  # Get the latest revision of the official RL10.x.x ServerTemplate
  @rl10_st = last(rs_cm.publications.index(filter: ["name=="+$param_starting_st]))
  if empty?(@rl10_st)
    raise "Cloud not find ServerTemplate, "+$param_starting_st+" in the MultiCloud MarketPlace."
  end
  
  # If RL10 published ST is found, import it and then find it in the account
  @rl10_st.import()
  call st.find_st($param_starting_st) retrieve @rl10_st
  
  # Is there already a PFT Base Linux ST in the account?
  call st.find_st($pft_base_st_name) retrieve @pft_base_st
  
  # If so, delete it so we can create a fresh on using the latest published RL10 ST
  if logic_not(empty?(@pft_base_st))
    @pft_base_st.destroy()
  end
  
  # Create a new ST based on the published ST
  @rl10_st.clone(server_template: {name: $pft_base_st_name, description: $pft_base_st_name})
  # Find the newly created ST
  call st.find_st($pft_base_st_name) retrieve @pft_base_st
  
  # Check that the official PFT Base MCIs are available in the account
  foreach $os in keys($map_mci_info) do
    $custom_mci = map($map_mci_info, $os, "custom_mci_name")
    call mci.find_mci($custom_mci) retrieve @pft_mci
    if empty?(@pft_mci)
      raise "Cloud not find MCI, " + $custom_mci + "in the Account. Be sure to run the MCI Setup CAT."
    end
    # else add it to the ST we just created and make it default
    @st_mci = rs_cm.server_template_multi_cloud_images.create(server_template_multi_cloud_image: {multi_cloud_image_href: @pft_mci.href, server_template_href: @pft_base_st.href})
    @st_mci.make_default()
  end  
end