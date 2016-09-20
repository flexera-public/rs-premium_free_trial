name "LIB - ServerTemplate Utilities"
rs_ca_ver 20160622
short_description "RCL definitions and resources for working with ServerTemplates"

package "util/server_templates"

import "util/err"

permission "import_servertemplates" do
  actions   "rs_cm.import"
  resources "rs_cm.publications"
end

# Imports the server templates found in the given map.
# It assumes a "name" and "rev" mapping
define importServerTemplate($stmap) do
  foreach $st in keys($stmap) do
    $server_template_name = map($stmap, $st, "name")
    $server_template_rev = map($stmap, $st, "rev")
    @pub_st = rs_cm.publications.index(filter: ["name=="+$server_template_name, "revision=="+$server_template_rev])
    @pub_st.import()
  end
end

# Runs a rightscript without specified inputs on the given target node 
define run_script($script_name, @target) do
  @script = rs_cm.right_scripts.get(latest_only: true, filter: [ join(["name==",$script_name]) ])
  $right_script_href=@script.href
  
  call get_instance_collection(@target) retrieve @target_instances

  @task = @target_instances.run_executable(right_script_href: $right_script_href)
  if @task.summary =~ "failed"
    raise "Failed to run " + $script_name + " on server, " + @target.href
  end 
end

# Runs a recipe with no inputs on the given target node 
define run_recipe_no_inputs(@target, $recipe_name) do

  call get_instance_collection(@target) retrieve @target_instances

  @task = @target_instances.run_executable(recipe_name: $recipe_name)
  sleep_until(@task.summary =~ "^(completed|failed)")
  if @task.summary =~ "failed"
    raise "Failed to run " + $recipe_name
  end
end

# Runs a recipe with specified inputs on the given target node 
define run_recipe_inputs(@target, $recipe_name, $recipe_inputs) do
  
  call get_instance_collection(@target) retrieve @target_instances
  
  @task = @target_instances.run_executable(recipe_name: $recipe_name, inputs: $recipe_inputs)
  sleep_until(@task.summary =~ "^(completed|failed)")
  if @task.summary =~ "failed"
    raise "Failed to run " + $recipe_name
  end
end

# return the single instance for a server or the 1 or more instances for a server-array
define get_instance_collection(@target) return @target_instances do
  $target_type = type(@target)
  if equals?($target_type, "rs_cm.servers")
    @target_instances = @target.current_instance()
  elsif equals?($target_type, "rs_cm.server_arrays")
    @target_instances = @target.current_instances()
  elsif equals?($target_type, "rs_cm.instances")
    @target_instances = @target
  else
    call err.log("get_instance_collection: Unrecognized target type: "+to_s($target_type), to_s(@target))
  end
end