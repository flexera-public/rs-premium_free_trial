# This CAT is used to create and manage a PFT Base Docker ServerTemplate
# The intent is that this CAT is run in an account when an updated RL10 Base Linux ServerTemplate is available.
# It starts with the PFT Base Linux ST and adds RigthScripts to make it a Docker host.

name "PFT Admin CAT - PFT Base Docker ServerTemplate Setup/Maintenance"
rs_ca_ver 20161221
short_description "Used for PFT account administration.\n
This CAT is used to create/update/maintain the PFT Base Docker ServerTemplate."

import "pft/server_templates_utilities", as: "st"
import "pft/mci"

operation "launch" do
  description "Manage the ST"
  definition "manage_st"
end

define manage_st() do
  $pft_base_linux_st_name = "PFT Base Linux ServerTemplate" # Name of the Base Linux ST used by PFT assets.
  $pft_base_docker_st_name = "PFT Base Docker" # Name of the Docker ST being created..

  # make sure the linux ST is set up and if so, clone it as the basis for the Docker ST
  call st.find_st($pft_base_linux_st_name) retrieve @base_linux_st
  if empty?(@base_linux_st)
    raise "ServerTemplate, "+$pft_base_linux_st_name+"not found. Need to run Base Linux ServerTemplate management CAT first."
  end
  
  # if the docker ST is already here, delete it so we can build it from scratch
  # Is there already a PFT Base Linux ST in the account?
  call st.find_st($pft_base_docker_st_name) retrieve @pft_base_docker_st
  if logic_not(empty?(@pft_base_docker_st))
    @pft_base_docker_st.destroy()
  end
  
  # Clone the base linux ST to make a fresh Docker ST and find the docker ST.
  @base_linux_st.clone(server_template: {name: $pft_base_docker_st_name, description: $pft_base_docker_st_name})
  call st.find_st($pft_base_docker_st_name) retrieve @pft_base_docker_st

  # Import the RightScripts to be added to the cloned ST and add them to the ST.
  $docker_boot_rightscripts = [ "SYS Packages Install", "SYS Swap Setup", "SYS docker-compose install latest", "SYS docker engine install latest", "SYS docker TCP enable", "RL10 Linux Enable Docker Support (Beta)" ]
  foreach $docker_rs in $docker_boot_rightscripts do
    @pub_rightscript = last(rs_cm.publications.index(filter: ["name=="+$docker_rs]))
    @pub_rightscript.import()
    @script = rs_cm.right_scripts.get(latest_only: true, filter: ["name=="+$docker_rs])
    $script_href = @script.href
    @pft_base_docker_st.runnable_bindings().create(runnable_binding: {right_script_href: $script_href, sequence: "boot"})
  end
  
  $docker_operational_rightscripts = [ "APP docker services compose", "APP docker services up" ]
  foreach $docker_rs in $docker_operational_rightscripts do
    @pub_rightscript = last(rs_cm.publications.index(filter: ["name=="+$docker_rs]))
    @pub_rightscript.import()
    @script = rs_cm.right_scripts.get(latest_only: true, filter: ["name=="+$docker_rs])
    $script_href = @script.href
    @pft_base_docker_st.runnable_bindings().create(runnable_binding: {right_script_href: $script_href, sequence: "operational"})
  end

end