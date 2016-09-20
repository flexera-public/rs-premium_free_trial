name "LIB - Account Utilities"
rs_ca_ver 20160622
short_description "RCL definitions for gathering account and related information."

package "util/account"



# Returns either an RDP or SSH link for the given server.
# This link can be provided as an output for a CAT and the user can select it to to get the
# RDP or SSH file just like in Cloud Management.
#
# INPUTS:
#   @server - server resource for which you want the link
#   $link_type - "SSH" or "RDP" to indicate which type of access link you want back.
#   $shard - the API shard to use. This can be found using the "find_shard.rb" definition.
#   $account_number - the account number. This can be found using the "find_account_number.rb" definition.
#
define get_server_access_link(@server, $link_type, $shard, $account_number) return $server_access_link do
  
  $rs_endpoint = "https://us-"+$shard+".rightscale.com"
    
  $instance_href = @server.current_instance().href
  
  $response = http_get(
    url: $rs_endpoint+"/api/instances",
    headers: { 
    "X-Api-Version": "1.6",
    "X-Account": $account_number
    }
   )
  
  $instances = $response["body"]
  
  $instance_of_interest = select($instances, { "href" : $instance_href })[0]
#  rs_cm.audit_entries.create(notify: "None", audit_entry: { auditee_href: @server, summary: join(["instance of interest"]), detail: to_s($instance_of_interest)})
    
  $legacy_id = $instance_of_interest["legacy_id"]  

  $cloud_id = $instance_of_interest["links"]["cloud"]["id"]
  
  $instance_public_ips = $instance_of_interest["public_ip_addresses"]
  $instance_private_ips = $instance_of_interest["private_ip_addresses"]
  $instance_ip = switch(empty?($instance_public_ips), to_s($instance_private_ips[0]), to_s($instance_public_ips[0]))
#  rs_cm.audit_entries.create(notify: "None", audit_entry: { auditee_href: @server, summary: join(["instance_ip: ", $instance_ip]), detail: ""})

  $server_access_link_root = "https://my.rightscale.com/acct/"+$account_number+"/clouds/"+$cloud_id+"/instances/"+$legacy_id
  
  if $link_type == "RDP"
    $server_access_link = $server_access_link_root +"/rdp?host=" + $instance_ip
  elsif $link_type == "SSH"
    $server_access_link = $server_access_link_root +"/managed_ssh.jnlp?host=" + $instance_ip
  else
    raise "Incorrect link_type, " + $link_type + ", passed to get_server_access_link()."
  end
  
#  rs_cm.audit_entries.create(notify: "None", audit_entry: { auditee_href: @server, summary: "access link", detail: $server_access_link})

end


# Returns the RightScale account number in which the CAT was launched.
define find_account_number() return $rs_account_number do
  $cloud_accounts = to_object(first(rs_cm.cloud_accounts.get()))
  @info = first(rs_cm.cloud_accounts.get())
  $info_links = @info.links
  $rs_account_info = select($info_links, { "rel": "account" })[0]
  $rs_account_href = $rs_account_info["href"]  
    
  $rs_account_number = last(split($rs_account_href, "/"))
  #rs_cm.audit_entries.create(notify: "None", audit_entry: { auditee_href: @deployment, summary: "rs_account_number" , detail: to_s($rs_account_number)})
end
  
# Returns the RightScale shard for the account the given CAT is launched in.
# It relies on the fact that when a CAT is launched, the resultant deployment description includes a link
# back to Self-Service. 
# This link is exploited to identify the shard.
# Of course, this is somewhat dangerous because if the deployment description is changed to remove that link, 
# this code will not work.
# Similarly, since the deployment description is also based on the CAT description, if the CAT author or publisher
# puts something like "selfservice-8" in it for some reason, this code will likely get confused.
# However, for the time being it's fine.
define find_shard(@deployment) return $shard_number do
  
  $deployment_description = @deployment.description
  #rs_cm.audit_entries.create(notify: "None", audit_entry: { auditee_href: @deployment, summary: "deployment description" , detail: $deployment_description})
  
  # initialize a value
  $shard_number = "UNKNOWN"
  foreach $word in split($deployment_description, "/") do
    if $word =~ "selfservice-" 
    #rs_cm.audit_entries.create(notify: "None", audit_entry: { auditee_href: @deployment, summary: join(["found word:",$word]) , detail: ""}) 
      foreach $character in split($word, "") do
        if $character =~ /[0-9]/
          $shard_number = $character
          #rs_cm.audit_entries.create(notify: "None", audit_entry: { auditee_href: @deployment, summary: join(["found shard:",$character]) , detail: ""}) 
        end
      end
    end
  end
end
