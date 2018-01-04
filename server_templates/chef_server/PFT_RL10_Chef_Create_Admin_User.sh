#! /usr/bin/sudo /bin/bash
# ---
# RightScript Name: PFT RL10 Chef Create Admin User
# Description: Creates a new administrator user on a chef server using chef-server-ctl,
#   as described at -> (https://docs.chef.io/install_server.html#standalone)
# Inputs:
#   CHEF_ADMIN_USERNAME:
#     Category: CHEF
#     Description: Chef administrator users username
#     Input Type: single
#     Required: true
#     Advanced: false
#   CHEF_ADMIN_EMAIL:
#     Category: CHEF
#     Description: Chef administrator users email address
#     Input Type: single
#     Required: true
#     Advanced: false
#   CHEF_ADMIN_FIRST_NAME:
#     Category: CHEF
#     Description: Chef administrator users first name
#     Input Type: single
#     Required: true
#     Advanced: false
#   CHEF_ADMIN_LAST_NAME:
#     Category: CHEF
#     Description: Chef administrator users last name
#     Input Type: single
#     Required: true
#     Advanced: false
#   CHEF_ADMIN_PASSWORD:
#     Category: CHEF
#     Description: Desired password for the Chef administrator user
#     Input Type: single
#     Required: true
#     Advanced: false
# Attachments: []
# ...

set -e

if [ ! -e /srv/chef-server/admin-users ]; then
  mkdir -p /srv/chef-server/admin-users
fi

if [ ! -f "/srv/chef-server/admin-users/$CHEF_ADMIN_USERNAME.pem" ]; then
  chef-server-ctl user-create "$CHEF_ADMIN_USERNAME" "$CHEF_ADMIN_FIRST_NAME" "$CHEF_ADMIN_LAST_NAME" "$CHEF_ADMIN_EMAIL" "$CHEF_ADMIN_PASSWORD" --filename "/srv/chef-server/admin-users/$CHEF_ADMIN_USERNAME.pem"
fi
