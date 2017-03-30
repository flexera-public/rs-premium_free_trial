#! /usr/bin/sudo /bin/bash
# ---
# RightScript Name: HAProxy Install - chef
# Description: 'Installs HAProxy and sets up monitoring for the HAProxy process. '
# Inputs:
#   BALANCE_ALGORITHM:
#     Category: Load Balancer
#     Description: 'The algorithm that the load balancer will use to direct traffic.
#       Example: roundrobin'
#     Input Type: single
#     Required: true
#     Advanced: false
#     Default: text:roundrobin
#   HEALTH_CHECK_URI:
#     Category: Load Balancer
#     Description: 'The URI that the load balancer will use to check the health of a
#       server. It is only used for HTTP (not HTTPS) requests. Example: /'
#     Input Type: single
#     Required: true
#     Advanced: false
#     Default: text:/
#   SESSION_STICKINESS:
#     Category: Load Balancer
#     Description: 'Determines session stickiness. Set to ''True'' to use session stickiness,
#       where the load balancer will reconnect a session to the last server it was connected
#       to (via a cookie). Set to ''False'' if you do not want to use sticky sessions;
#       the load balancer will establish a connection with the next available server.
#       Example: true'
#     Input Type: single
#     Required: true
#     Advanced: false
#     Default: text:true
#     Possible Values:
#     - text:true
#     - text:false
#   POOLS:
#     Category: Load Balancer
#     Description: 'List of application pools for which the load balancer will create
#       backend pools to answer website requests. The order of the items in the list
#       will be preserved when answering to requests. Last entry will be considered
#       as the default backend and will answer for all requests. Application servers
#       can provide any number of URIs or FQDNs (virtual host paths) to join corresponding
#       server pool backends. The pool names can have only alphanumeric characters and
#       underscores. Example: mysite, _api, default123'
#     Input Type: single
#     Required: true
#     Advanced: false
#     Default: text:default
#   SSL_CERT:
#     Category: Load Balancer
#     Description: PEM formatted string containing SSL certificates and keys for SSL
#       encryption. Unset this to configure HAProxy without SSL encryption.
#     Input Type: single
#     Required: false
#     Advanced: false
#   SSL_INCOMING_PORT:
#     Category: Load Balancer
#     Description: The port on which HAProxy listens for HTTPS requests
#     Input Type: single
#     Required: false
#     Advanced: false
#   STATS_PASSWORD:
#     Category: Load Balancer
#     Description: 'The password that is required to access the load balancer statistics
#       report page. Example: cred:STATS_PASSWORD'
#     Input Type: single
#     Required: false
#     Advanced: false
#   STATS_USER:
#     Category: Load Balancer
#     Description: 'The username that is required to access the load balancer statistics
#       report page. Example: cred:STATS_USER'
#     Input Type: single
#     Required: false
#     Advanced: false
#   STATUS_URI:
#     Category: Load Balancer
#     Description: 'The URI for the load balancer statistics report page. This page
#       lists the current session, queued session, response error, health check error,
#       server status, etc. for each load balancer group. Example: /haproxy-status'
#     Input Type: single
#     Required: false
#     Advanced: false
#     Default: text:/haproxy-status
# Attachments: []
# ...

set -e

HOME=/home/rightscale
export PATH=${PATH}:/usr/local/sbin:/usr/local/bin

/sbin/mkhomedir_helper rightlink

export chef_dir=$HOME/.chef
mkdir -p $chef_dir

ssl_cert=''
if [ -n "$SSL_CERT" ];then
cat <<EOF>/tmp/cert
$SSL_CERT
EOF
ssl_output="$(cat /tmp/cert | awk 1 ORS='\\n')"
  ssl_cert="\"ssl_cert\":\"${ssl_output}\","
fi

ssl_incoming_port=''
if [ -n "$SSL_INCOMING_PORT" ];then
  ssl_incoming_port="\"ssl_incoming_port\":\"$SSL_INCOMING_PORT\","
fi
stats_password=''
if [ -n "$STATS_PASSWORD" ];then
  stats_password="\"stats_password\":\"$STATS_PASSWORD\","
fi
stats_user=''
if [ -n "$STATS_USER" ];then
  stats_user="\"stats_user\":\"$STATS_USER\","
fi

#get instance data to pass to chef server
instance_data=$(rsc --rl10 cm15 index_instance_session  /api/sessions/instance)
instance_uuid=$(echo $instance_data | rsc --x1 '.monitoring_id' json)
instance_id=$(echo $instance_data | rsc --x1 '.resource_uid' json)

if [ -e $chef_dir/chef.json ]; then
  rm -f $chef_dir/chef.json
fi

# allow ohai to work in VPC
if [[ $(dmidecode | grep -i amazon) ]] ; then
 mkdir -p /etc/chef/ohai/hints && touch ${_}/ec2.json
fi

# add the rightscale env variables to the chef runtime attributes
# http://docs.rightscale.com/cm/ref/environment_inputs.html
cat <<EOF> $chef_dir/chef.json
{
  "name": "${HOSTNAME}",
  "rightscale":{
    "instance_uuid":"$instance_uuid",
    "instance_id":"$instance_id"
  },
  "apt": {
    "compile_time_update": "true"
  },
  "rs-haproxy": {
    "balance_algorithm": "$BALANCE_ALGORITHM",
    "health_check_uri": "$HEALTH_CHECK_URI",
    "session_stickiness": "$SESSION_STICKINESS",
    $ssl_cert
    $ssl_incoming_port
    $stats_password
    $stats_user
    "stats_user":"$STATS_USER",
    "stats_uri": "$STATUS_URI",
    "pools":["$POOLS"]
  },
  "run_list": ["recipe[apt]","recipe[rs-haproxy]","recipe[rs-haproxy::tags]",
  "recipe[rs-haproxy::collectd]"]
}
EOF


chef-client -j $chef_dir/chef.json
