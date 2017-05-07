name "LIB - ServerArray Utilities"
rs_ca_ver 20160622
short_description "RCL definitions and resources for working with ServerArrays"

package "pft/server_array_utilities"

import "pft/server_templates_utilities"

# Scale out (add) server
define scale_out_array(@app_server, @lb_server) do
  task_label("Scale out application server.")
  @task = @app_server.launch()

  $wake_condition = "/^(operational|stranded|stranded in booting|stopped|terminated|inactive|error)$/"
  sleep_until all?(@app_server.current_instances().state[], $wake_condition)
  if !all?(@app_server.current_instances().state[], "operational")
    raise "Some instances failed to start"    
  end
     
  call apply_costcenter_tag(@app_server)

end

# Scale in (remove) server
define scale_in_array(@app_server) do
  task_label("Scale in web server array.")

  @terminable_servers = select(@app_server.current_instances(), {"state":"/^(operational|stranded)/"})
  if size(@terminable_servers) > 0 
    # Terminate the oldest instance in the array.
    @server_to_terminate = first(@terminable_servers)
    @server_to_terminate.terminate()
    # Wait for the server to be no longer of this mortal coil
    sleep_until(@server_to_terminate.state != "operational" )
  else
    rs_cm.audit_entries.create(audit_entry: {auditee_href: @app_server.href, summary: "Scale In: No terminable server currently found in the server array"})
  end
  
end


# Apply the cost center tag to the server array instance(s)
define apply_costcenter_tag(@server_array) do
  # Get the tags for the first instance in the array
  $tags = rs_cm.tags.by_resource(resource_hrefs: [@server_array.current_instances().href[][0]])
  # Pull out only the tags bit from the response
  $tags_array = $tags[0][0]['tags']

  # Loop through the tags from the existing instance and look for the costcenter tag
  $costcenter_tag = ""
  foreach $tag_item in $tags_array do
    $tag = $tag_item['name']
    if $tag =~ /costcenter:id/
      $costcenter_tag = $tag
    end
  end  

  # Now apply the costcenter tag to all the servers in the array - including the one that was just added as part of the scaling operation
  rs_cm.tags.multi_add(resource_hrefs: @server_array.current_instances().href[], tags: [$costcenter_tag])
end

