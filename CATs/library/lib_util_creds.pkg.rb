# Required prolog
name 'LIB - Credential utilities'
rs_ca_ver 20160622
short_description "Credential related utilities"

package "util/creds"

# Creates CREDENTIAL objects in Cloud Management for each of the named items in the given array.
define createCreds($credname_array) do
  foreach $cred_name in $credname_array do
    @cred = rs_cm.credentials.get(filter: [ join(["name==",$cred_name]) ])
    if empty?(@cred) 
      $cred_value = join(split(uuid(), "-"))[0..14] # max of 16 characters for mysql username and we're adding a letter next.
      $cred_value = "a" + $cred_value # add an alpha to the beginning of the value - just in case.
      @task=rs_cm.credentials.create({"name":$cred_name, "value": $cred_value})
    end
  end
end


# Used to get a credential
# Requires admin permission
define get_cred($cred_name) return $cred_value do
  @cred = rs_cm.credentials.get(filter: [ "name=="+$cred_name ], view: "sensitive") 
  $cred_hash = to_object(@cred)
  $cred_value = ""
  foreach $detail in $cred_hash["details"] do
    if $detail["name"] == $cred_name
      $cred_value = $detail["value"]
    end
  end
end





