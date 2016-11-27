#! /usr/bin/sudo /bin/bash
# ---
# RightScript Name: RL10 Chef Server Schedule Backup
# Description: 'Creates a volume and attaches it to the server '
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
#   SCHEDULE_HOUR:
#     Category: Backup
#     Description: "The hour to schedule the backup on. This value should abide by crontab
#       syntax. Use '*' for taking\" +\r\n    ' backups every hour. Example: 23"
#     Input Type: single
#     Required: true
#     Advanced: false
#   SCHEDULE_MINUTE:
#     Category: Backup
#     Description: 'The minute to schedule the backup on. This value should abide by
#       crontab syntax. Example: 30'
#     Input Type: single
#     Required: true
#     Advanced: false
#   SCHEDULE_ENABLE:
#     Category: Backup
#     Description: Enable or disable periodic backup schedule
#     Input Type: single
#     Required: true
#     Advanced: false
#     Possible Values:
#     - text:true
#     - text:false
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
   "schedule":{
     "enable":"$SCHEDULE_ENABLE",
     "minute":"$SCHEDULE_MINUTE",
     "hour":"$SCHEDULE_HOUR"
  }
	},

	"run_list": ["recipe[chef-server-blueprint::schedule]"]
}
EOF

chef-solo -l $LOG_LEVEL -L /var/log/chef.log -j $chef_dir/chef.json -c $chef_dir/solo.rb
