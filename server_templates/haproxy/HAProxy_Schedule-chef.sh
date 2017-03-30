#! /usr/bin/sudo /bin/bash
# ---
# RightScript Name: HAProxy Schedule - chef
# Description: Configure cron to periodically run HAProxy Frontend Scrip
# Inputs:
#   SCHEDULE_ENABLE:
#     Category: Load Balancer
#     Description: 'Enable or disable periodic queries of application servers in the
#       deployment. '
#     Input Type: single
#     Required: true
#     Advanced: false
#     Default: text:true
#     Possible Values:
#     - text:true
#     - text:false
#   SCHEDULE_INTERVAL:
#     Category: Load Balancer
#     Description: 'Interval in minutes to run periodic queries of application servers
#       in the deployment. Example: 15'
#     Input Type: single
#     Required: true
#     Advanced: false
#     Default: text:15
# Attachments: []
# ...

set -e

HOME=/home/rightscale
export PATH=${PATH}:/usr/local/sbin:/usr/local/bin

sudo /sbin/mkhomedir_helper rightlink

export chef_dir=$HOME/.chef
mkdir -p $chef_dir

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
    "tags": [
    ]
  },
  "rightscale":{
    "instance_uuid":"$instance_uuid",
    "instance_id":"$instance_id"
  },
  "rs-haproxy": {
    "schedule":{
    "enable":"$SCHEDULE_ENABLE",
    "interval":"$SCHEDULE_INTERVAL"
    }
  },
  "run_list": ["recipe[rs-haproxy::schedule]"]
}
EOF



sudo chef-client -j $chef_dir/chef.json
