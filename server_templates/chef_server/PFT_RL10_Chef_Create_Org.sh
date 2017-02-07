#! /usr/bin/sudo /bin/bash
# ---
# RightScript Name: PFT RL10 Chef Create Org
# Description: Creates a new organization on a chef server using chef-server-ctl, as
#   described at -> (https://docs.chef.io/install_server.html#standalone)
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

if [ ! -e /srv/chef-server/orgs ]; then
  mkdir -p /srv/chef-server/orgs
fi

chef-server-ctl org-create "$CHEF_ORG_NAME" "$CHEF_ORG_NAME" --association_user "$CHEF_ADMIN_USERNAME" --filename "/srv/chef-server/orgs/$CHEF_ORG_NAME-validator.pem"
