name "LIB - Account Utilities"
rs_ca_ver 20160622
short_description "RCL definitions for gathering account and related information."

package "pft/account_utilities"



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
define find_account_number() return $account_id do
  $session = rs_cm.sessions.index(view: "whoami")
  $account_id = last(split(select($session[0]["links"], {"rel":"account"})[0]["href"],"/"))
end
  
# Returns the RightScale shard for the account the given CAT is launched in.
define find_shard() return $shard_number do
  call find_account_number() retrieve $account_number
  $account = rs_cm.get(href: "/api/accounts/" + $account_number)
  $shard_number = last(split(select($account[0]["links"], {"rel":"cluster"})[0]["href"],"/"))
end
