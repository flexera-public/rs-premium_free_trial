#! /usr/bin/sudo /bin/bash
# ---
# RightScript Name: RL10 Chef Server Backup
# Description: Backup the Chef Server to a Remote Object Store (ie. s3, google cloud
#   storage, or openstack swift)
# Inputs:
#   LOG_LEVEL:
#     Category: CHEF
#     Description: Chef solo Log Level
#     Input Type: single
#     Required: true
#     Advanced: false
#     Possible Values:
#     - text:info
#     - text:warn
#     - text:fatal
#     - text:error
#     - text:debug
#   STORAGE_ACCOUNT_ENDPOINT:
#     Category: Backup
#     Description: 'The endpoint URL for the storage cloud. This is used to override
#       the default endpoint or for generic storage clouds such as Swift Example: http://endpoint_ip:5000/v2.0/tokens'
#     Input Type: single
#     Required: false
#     Advanced: false
#   BACKUP_LINEAGE:
#     Category: Backup
#     Description: Name of the backup
#     Input Type: single
#     Required: false
#     Advanced: false
#   STORAGE_ACCOUNT_ID:
#     Category: Backup
#     Description: "In order to write the Chef Server backup file to the specified cloud
#       storage location you need to provide cloud authentication credentials\r\n    For
#       Amazon S3, use your AWS secret access key\r\n     (e.g., cred:AWS_SECRET_ACCESS_KEY).\r\n
#       \\    For Rackspace Cloud Files, use your Rackspace account API key     (e.g.,
#       cred:RACKSPACE_AUTH_KEY). Example: cred:AWS_SECRET_ACCESS_KEY"
#     Input Type: single
#     Required: false
#     Advanced: false
#   STORAGE_ACCOUNT_PROVIDER:
#     Category: Backup
#     Description: "In order to write the Chef Server backup file to the specified cloud
#       storage location\r\n   you need to provide cloud authentication credentials.\r\n
#       \\   For Amazon S3, use your Amazon access key ID\r\n    (e.g., cred:AWS_ACCESS_KEY_ID).
#       For Rackspace Cloud Files, use your\r\n     Rackspace login username (e.g.,
#       cred:RACKSPACE_USERNAME).\r\n    \" For OpenStack Swift the format is: 'tenantID:username'.\r\n
#       \\    Example: cred:AWS_ACCESS_KEY_ID"
#     Input Type: single
#     Required: false
#     Advanced: false
#     Possible Values:
#     - text:aws
#     - text:google
#     - text:rackspace
#   STORAGE_ACCOUNT_SECRET:
#     Category: Backup
#     Description: "In order to write the Chef Server backup file to the specified cloud
#       storage location you need to provide cloud authentication credentials\r\n    For
#       Amazon S3, use your AWS secret access key\r\n     (e.g., cred:AWS_SECRET_ACCESS_KEY).\r\n
#       \\    For Rackspace Cloud Files, use your Rackspace account API key     (e.g.,
#       cred:RACKSPACE_AUTH_KEY). Example: cred:AWS_SECRET_ACCESS_KEY"
#     Input Type: single
#     Required: false
#     Advanced: false
#   STORAGE_CONTAINER:
#     Category: Backup
#     Description: "The cloud storage location where the dump file will be saved to\r\n
#       \\   or restored from. For Amazon S3, use the bucket name.\r\n    For Rackspace
#       Cloud Files, use the container name.\r\n    Example: db_dump_bucket"
#     Input Type: single
#     Required: false
#     Advanced: false
# Attachments: []
# ...

set -e

HOME=/home/rightscale

/sbin/mkhomedir_helper rightlink

export chef_dir=$HOME/.chef
mkdir -p $chef_dir

if [ -e $chef_dir/chef.json ]; then
  rm -f $chef_dir/chef.json
fi

#get instance data to pass to chef server
instance_data=$(rsc --rl10 cm15 index_instance_session  /api/sessions/instance)
instance_uuid=$(echo $instance_data | rsc --x1 '.monitoring_id' json)
instance_id=$(echo $instance_data | rsc --x1 '.resource_uid' json)

if [ -e $chef_dir/chef.json ]; then
  rm -f $chef_dir/chef.json
fi
# add the rightscale env variables to the chef runtime attributes
# http://docs.rightscale.com/cm/ref/environment_inputs.html
cat <<EOF> $chef_dir/chef.json
{
	"name": "${HOSTNAME}",
	"normal": {
		"tags": []
	},
 
 "apt":{"compile_time_update":"true"},
 "build-essential":{"compile_time":"true"},

 "rightscale": {
    "instance_uuid":"$instance_uuid",
    "instance_id":"$instance_id"
	},

	"chef-server-blueprint": {
   "backup":{
     "lineage":"$BACKUP_LINEAGE",
     "storage_account_provider":"$STORAGE_ACCOUNT_PROVIDER",
     "storage_account_id":"$STORAGE_ACCOUNT_ID",
     "storage_account_secret":"$STORAGE_ACCOUNT_SECRET",
     "storage_account_endpoint":"$STORAGE_ACCOUNT_ENDPOINT",
     "container":"$STORAGE_CONTAINER"
   }
	},

	"run_list": ["recipe[chef-server-blueprint::chef-ros-backup]"]
}
EOF

chef-solo -l $LOG_LEVEL -L /var/log/chef.log -j $chef_dir/chef.json -c $chef_dir/solo.rb
