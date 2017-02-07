#! /usr/bin/sudo /bin/bash
# ---
# RightScript Name: Chef Client Install
# Description: Installs the Chef Client and prepares system to access the Chef Server
# Inputs:
#   VERSION:
#     Category: CHEF
#     Description: 'Version of chef client to install.  Example: 11.6'
#     Input Type: single
#     Required: true
#     Advanced: false
#   CHEF_VALIDATION_KEY:
#     Category: CHEF
#     Description: 'The Chef Server Validation Key.  '
#     Input Type: single
#     Required: true
#     Advanced: false
#   CHEF_SERVER_URL:
#     Category: CHEF
#     Description: The Chef Server URL
#     Input Type: single
#     Required: true
#     Advanced: false
#   CHEF_VALIDATION_NAME:
#     Category: CHEF
#     Description: The Chef Server Validation Name
#     Input Type: single
#     Required: true
#     Advanced: false
#   CHEF_SERVER_SSL_CERT:
#     Category: CHEF
#     Description: The Chef Server SSL Certificate.  Use knife ssl fetch to retrieve
#       the ssl cert.
#     Input Type: single
#     Required: true
#     Advanced: false
#   LOG_LEVEL:
#     Category: CHEF
#     Description: 'The level of logging to be stored in a log file. Possible levels:
#       :auto (default), :debug, :info, :warn, :error, or :fatal. '
#     Input Type: single
#     Required: false
#     Advanced: false
#     Default: text::info
#     Possible Values:
#     - text::auto
#     - text::debug
#     - text::info
#     - text::warn
#     - text::error
#     - text::fatal
#   CHEF_ENVIRONMENT:
#     Category: CHEF
#     Description: The name of the Chef environment.
#     Input Type: single
#     Required: true
#     Advanced: false
#     Default: text:_default
# Attachments: []
# ...

set -e

HOME=/home/rightscale

if [[ ! -z $VERSION ]]; then
  version="-v $VERSION"
fi

if [ ! -e /usr/bin/chef-client ]; then
  curl -L https://www.opscode.com/chef/install.sh | sudo bash -s -- $version
fi

/sbin/mkhomedir_helper rightlink
export chef_dir=/etc/chef
mkdir -p $chef_dir

cat <<EOF> $chef_dir/validation.pem
$CHEF_VALIDATION_KEY
EOF

mkdir -p $chef_dir/trusted_certs
#get this by knife ssl fetch
cat <<EOF> $chef_dir/trusted_certs/chef-server.crt
$CHEF_SERVER_SSL_CERT
EOF


if [ -e $chef_dir/client.rb ]; then
  rm -fr $chef_dir/client.rb
fi

#allow ohai to work for the clouds
if [[ $(dmidecode | grep -i amazon) ]] ; then
 mkdir -p /etc/chef/ohai/hints && touch ${_}/ec2.json
fi
if [[ $(dmidecode | grep -i google) ]] ; then
 mkdir -p /etc/chef/ohai/hints && touch ${_}/gce.json
fi
if [[ $(dmidecode | grep -i 'Microsoft Corporation') ]] ; then
 mkdir -p /etc/chef/ohai/hints && touch ${_}/azure.json
fi

cat <<EOF> $chef_dir/client.rb
log_level              $LOG_LEVEL
log_location           '/var/log/chef.log'
chef_server_url        "$CHEF_SERVER_URL"
validation_client_name "$CHEF_VALIDATION_NAME"
node_name              "${HOSTNAME}"
cookbook_path          "/var/chef/cache/cookbooks/"
validation_key         "$chef_dir/validation.pem"
environment            "$CHEF_ENVIRONMENT"
EOF

# test config and register node.
chef-client
