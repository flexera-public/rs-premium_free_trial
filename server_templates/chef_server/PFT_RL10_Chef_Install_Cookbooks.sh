#! /usr/bin/sudo /bin/bash
# ---
# RightScript Name: PFT RL10 Chef Install Cookbooks
# Description: Installs all the cookbooks for rs-haproxy
# Inputs:
#   CHEF_ADMIN_USERNAME:
#     Category: CHEF
#     Description: Chef administrator users username
#     Input Type: single
#     Required: true
#     Advanced: false
#   CHEF_ORG_NAME:
#     Category: CHEF
#     Description: Short name for new org (also used as the long name)
#     Input Type: single
#     Required: true
#     Advanced: true
#     Default: text:pft
# Attachments: []
# ...

set -e

if [ -z "`which berkshelf`"]; then
  apt-add-repository ppa:brightbox/ruby-ng -y
  apt-get update
  apt-get install -y ruby2.2 ruby2.2-dev

  gem2.2 install berkshelf -v 5.6.5
fi

cd /tmp
cat > berkshelf.json << EOF
{
  "chef": {
    "chef_server_url": "https://localhost/organizations/$CHEF_ORG_NAME",
    "client_key": "/srv/chef-server/admin-users/$CHEF_ADMIN_USERNAME.pem",
    "validation_key": "/srv/chef-server/orgs/$CHEF_ORG_NAME-validator.pem",
    "node_name": "$CHEF_ADMIN_USERNAME"
  },
  "ssl": {
    "verify": false
  }
}
EOF
git clone https://github.com/rightscale-cookbooks/rs-haproxy.git
cd /tmp/rs-haproxy
git checkout v1.2.4
berks install --except integration test && berks upload --except integration test -c /tmp/berkshelf.json

git clone https://github.com/rightscale-cookbooks/rs-mysql.git /tmp/rs-mysql
cd /tmp/rs-mysql
git checkout v2.0.1
berks install && berks upload -c /tmp/berkshelf.json

git clone https://github.com/rightscale-cookbooks/rs-application_php.git /tmp/rs-application_php
cd /tmp/rs-application_php
git checkout v2.0.1
berks install && berks upload -c /tmp/berkshelf.json
