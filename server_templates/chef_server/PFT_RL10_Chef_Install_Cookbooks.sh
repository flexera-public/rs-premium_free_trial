#! /usr/bin/sudo /bin/bash
# ---
# RightScript Name: PFT RL10 Chef Create Org
# Description: Creates a new organization on a chef server using
#   chef-server-ctl, as described at ->
#   (https://docs.chef.io/install_server.html#standalone)
# Inputs: {}
# Attachments: []
# ...

set -e


apt-add-repository ppa:brightbox/ruby-ng -y
apt-get update
apt-get install -y ruby2.2

gem2.2 install berkshelf

cd /tmp

git clone https://github.com/rightscale-cookbooks/rs-haproxy.git
