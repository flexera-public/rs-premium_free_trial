name "LIB - ServerTemplate Utilities"
rs_ca_ver 20160622
short_description "RCL definitions and resources for working with ServerTemplates"

package "util/server_array"

# Scale out (add) server
define scale_out_array(@app_server, @lb_server) do
  task_label("Scale out application server.")
  @task = @app_server.launch(inputs: {})

  $wake_condition = "/^(operational|stranded|stranded in booting|stopped|terminated|inactive|error)$/"
  sleep_until all?(@app_server.current_instances().state[], $wake_condition)
  if !all?(@app_server.current_instances().state[], "operational")
    raise "Some instances failed to start"    
  end
  
  # Now execute post launch scripts to finish setting up the server.
  concurrent do
    call run_recipe_inputs(@app_server, "rs-application_php::collectd", {})  
    call run_recipe_inputs(@app_server, "rs-application_php::tags", {})  
  end
  
  # Tell the load balancer to find the new app server
  call run_recipe_inputs(@lb_server, "rs-haproxy::frontend", {})
    
  call apply_costcenter_tag(@app_server)

end
