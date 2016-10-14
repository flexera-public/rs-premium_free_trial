name "LIB - Error Handling Utilities"
rs_ca_ver 20160622
short_description "RCL definitions for error handling functions"

package "pft/err_utilities"

# Used for retry mechanism
define handle_retries($attempts) do
  if $attempts < 3
    $_error_behavior = "retry"
    sleep(60)
  end # If it fails 3 times just let it raise the error
end

# create an audit entry 
define log($summary, $details) do
  rs_cm.audit_entries.create(notify: "None", audit_entry: { auditee_href: @@deployment, summary: $summary , detail: $details})
end
