#! /usr/bin/sudo /bin/bash
# ---
# RightScript Name: HAProxy Frontend - chef
# Description: 'Queries for application servers in the deployment and adds them to the
#   corresponding backend pools served by the load balancer. '
# Inputs:
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
#     Required: false
#     Advanced: false
#   POOL_NAME:
#     Category: Load Balancer
#     Description: Used for the remote server for remote recipe calls.  Should be same
#       as Application Name
#     Input Type: single
#     Required: false
#     Advanced: true
#   APPLICATION_ACTION:
#     Category: Load Balancer
#     Description: Used for the remote server for remote recipe calls.  actions are
#       'attach' or 'detach'
#     Input Type: single
#     Required: false
#     Advanced: true
#   APPLICATION_BIND_IP:
#     Category: Load Balancer
#     Description: 'Used for the remote server for remote recipe calls.  example: 1.2.3.4'
#     Input Type: single
#     Required: false
#     Advanced: true
#   APPLICATION_BIND_PORT:
#     Category: Load Balancer
#     Description: 'Used for the remote server for remote recipe calls.  example: 8080'
#     Input Type: single
#     Required: false
#     Advanced: true
#   VHOST_PATH:
#     Category: Load Balancer
#     Description: 'Used for the remote server for remote recipe calls.  '
#     Input Type: single
#     Required: false
#     Advanced: true
#   APPLICATION_SERVER_ID:
#     Category: Load Balancer
#     Description: 'Used for the remote server for remote recipe calls.  '
#     Input Type: single
#     Required: false
#     Advanced: true
#   BALANCE_ALGORITHM:
#     Category: Load Balancer
#     Description: 'The algorithm that the load balancer will use to direct traffic.
#       Example: roundrobin'
#     Input Type: single
#     Required: false
#     Advanced: false
#   HEALTH_CHECK_URI:
#     Category: Load Balancer
#     Description: 'The URI that the load balancer will use to check the health of a
#       server. It is only used for HTTP (not HTTPS) requests. Example: /'
#     Input Type: single
#     Required: false
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
# Attachments: []
# ...

set -e
set +x

HOME=/home/rightscale
export PATH=${PATH}:/usr/local/sbin:/usr/local/bin

sudo /sbin/mkhomedir_helper rightlink

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
if [ -n "$SSL_CERT" ];then
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

if [ -e $chef_dir/chef.json ]; then
  rm -f $chef_dir/chef.json
fi

#get instance data to pass to chef server
instance_data=$(rsc --rl10 cm15 index_instance_session  /api/sessions/instance)
instance_uuid=$(echo $instance_data | rsc --x1 '.monitoring_id' json)
instance_id=$(echo $instance_data | rsc --x1 '.resource_uid' json)

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
  "rs-haproxy":{
    "pools":["$POOLS"],
    "balance_algorithm": "$BALANCE_ALGORITHM",
    "health_check_uri": "$HEALTH_CHECK_URI",
    "session_stickiness": "$SESSION_STICKINESS",
    $ssl_cert
    $ssl_incoming_port
    $stats_password
    $stats_user
    "stats_uri": "$STATUS_URI"
  },
  "remote_recipe": {
    "pool_name": "$POOL_NAME",
    "application_server_id": "$APPLICATION_SERVER_ID",
    "application_action": "$APPLICATION_ACTION",
    "application_bind_ip": "$APPLICATION_BIND_IP",
    "application_bind_port": "$APPLICATION_BIND_PORT",
    "vhost_path":"$VHOST_PATH"
  },
  "run_list": ["recipe[rs-haproxy::frontend]"]
}
EOF


sudo chef-client -j $chef_dir/chef.json
