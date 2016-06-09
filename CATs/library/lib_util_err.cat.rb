name "LIB - Error Handling Utilities"
rs_ca_ver 20160108
short_description "RCL definitions for error handling functions"

package "util/err"

# Used for retry mechanism
define handle_retries($attempts) do
  if $attempts < 3
    $_error_behavior = "retry"
    sleep(60)
  end # If it fails 3 times just let it raise the error
end
