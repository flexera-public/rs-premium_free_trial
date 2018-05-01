name "LIB - S3 Utilities"
rs_ca_ver 20161221
short_description "RCL definitions for generating S3 signed URL."

package "pft/s3_utilities"

# Returns a signed URL for an S3 object
define get_signed_url($bucket, $object) return $signed_url do

  call acct.find_shard() retrieve $shard
  $rs_endpoint = "https://us-"+$shard+".rightscale.com"

  # The information relatdd to the bucket file for which the authenticated URL is needed

  $cloud_num = "1"  # doesn't matter which cloud number - as long as it is a valid AWS cloud number as cloud 1 is
  
  # signed URLs have a limited lifespan
  $exp_seconds = 10*60 # a 10 minute expiry is more than sufficient
  $expiration = now() + $exp_seconds  # 24 hours from now
  $expiration_date = strftime($expiration, "%s") # convert to "unix" time
  
  $api_uri = "/api/cs_s3/objects/"+$bucket+"/"+$object+"/download?expires="+$expiration_date+"&cloud_id="+$cloud_num  
 
  # Make the special API call to get the signed URL
  call acct.find_account_number() retrieve $account_number
  $response = http_get(
    url: $rs_endpoint + $api_uri,
    headers: { 
    "X-Api-Version": "1.6",
    "X-Account": $account_number
    }
   )
  
  $signed_url = $response["body"]["SignedURL"]
end