#! /usr/bin/sudo /bin/bash
# ---
# RightScript Name: RL10 Chef Server Install
# Description: Install and configure the Chef Server
# Inputs:
#   CHEF_SERVER_FQDN:
#     Category: CHEF
#     Description: Chef Server Domain Name
#     Input Type: single
#     Required: true
#     Advanced: false
#   SMTP_RELAYHOST:
#     Category: CHEF
#     Description: The SMTP Relayhost
#     Input Type: single
#     Required: false
#     Advanced: true
#   SMTP_SASL_PASSWORD:
#     Category: CHEF
#     Description: The SMTP relayhost password
#     Input Type: single
#     Required: false
#     Advanced: true
#   SMTP_SASL_USER_NAME:
#     Category: CHEF
#     Description: The SMTP relayhost username.
#     Input Type: single
#     Required: false
#     Advanced: true
#   CHEF_NOTIFICATON_EMAIL:
#     Category: CHEF
#     Description: The email address for chef to use to send notifications and alerts
#       on the chef server.
#     Input Type: single
#     Required: true
#     Advanced: false
#   LOG_LEVEL:
#     Category: CHEF
#     Description: The log level for the chef install
#     Input Type: single
#     Required: true
#     Advanced: false
#     Possible Values:
#     - text:info
#     - text:warn
#     - text:fatal
#     - text:debug
#   CHEF_SERVER_ADDONS:
#     Category: CHEF
#     Description: A common separated list of chef server addons.  For more details
#       see https://github.com/chef-cookbooks/chef-server
#     Input Type: array
#     Required: true
#     Advanced: false
#     Default: array:["text:manage","text:reporting"]
#   COOKBOOK_VERSION:
#     Category: CHEF
#     Description: 'The chef-blue-print cookbook version/branch to use to install chef.  Use
#       the GIT SHA, branch or tag.  Example: v1.0.0'
#     Input Type: single
#     Required: false
#     Advanced: true
#     Default: text:v1.0.0
#   CHEF_SERVER_VERSION:
#     Category: CHEF
#     Description: 'Chef Server Version.  Leave unset to use the latest. Example: 12.4.1.  '
#     Input Type: single
#     Required: false
#     Advanced: true
#     Default: text:12.4.1-1
#   EMAIL_FROM_ADDRESS:
#     Category: CHEF
#     Description: The email address Chef Manage uses to send email from.  Sets manage.rb
#       email_from_address attribute.
#     Input Type: single
#     Required: true
#     Advanced: false
# Attachments: []
# ...

set -x
set -e

# https://github.com/berkshelf/berkshelf-api/issues/112
export LC_CTYPE=en_US.UTF-8

if [ ! -e /usr/bin/chef-client ]; then
  curl -L https://www.opscode.com/chef/install.sh | sudo bash
fi

chef_dir="/home/rightscale/.chef"

if [ -e $chef_dir/cookbooks ]; then
  echo "Chef Server Already installed.  Exiting."
  exit 0
fi

rm -rf $chef_dir
mkdir -p $chef_dir/chef-install
chmod -R 0777 $chef_dir/chef-install

mkdir -p $chef_dir/cookbooks
chown -R 0777 $chef_dir/cookbooks

#install packages when on ubuntu
if which apt-get >/dev/null 2>&1; then
  apt-get -y update
  apt-get install -y build-essential git #ruby2.0 ruby2.0-dev
fi

#install packages for centos
if which yum >/dev/null 2>&1; then
  yum groupinstall -y 'Development Tools'
  yum install -y libxml2 libxml2-devel libxslt libxslt-devel git
fi

#install berkshelf
/opt/chef/embedded/bin/gem install berkshelf -v '4.3.5' --no-ri --no-rdoc

#checkout the chef server cookbook and install dependent cookbooks using berkshelf
cd $chef_dir
branch=""
if [ -n "$COOKBOOK_VERSION" ];then
  branch="--branch ${COOKBOOK_VERSION}"
fi
git clone $branch https://github.com/RightScale-Services-Cookbooks/chef-server-blueprint.git
cd chef-server-blueprint


/opt/chef/embedded/bin/berks vendor $chef_dir/cookbooks

cd $HOME
if [ -e $chef_dir/chef.json ]; then
  rm -f $chef_dir/chef.json
fi

#convert input array to array for json in chef.json below
IFS=","
addons_array=`echo $CHEF_SERVER_ADDONS | awk -v RS='' -v OFS='","' 'NF { $1 = $1; print "\"" $0 "\"" }'`
IFS=""

chef_version=""
if [ -n "$CHEF_SERVER_VERSION" ];then
 chef_version="\"version\":\"$CHEF_SERVER_VERSION\","
fi

#setup chef manage
mkdir -p /etc/chef-manage/
cat <<EOF>> /etc/chef-manage/manage.rb
email_from_address "$EMAIL_FROM_ADDRESS"
EOF

cat <<EOF> $chef_dir/chef.json
{
  "chef-server": {
    "accept_license": true,
    "api_fqdn": "$CHEF_SERVER_FQDN",
    $chef_version
    "addons":  [$addons_array],
    "configuration":{
    "notification_email":"$CHEF_NOTIFICATON_EMAIL"
    }
  },
  "rsc_postfix":{
    "smtp_sasl_user_name":"$SMTP_SASL_USER_NAME",
    "smtp_sasl_passwd":"$SMTP_SASL_PASSWORD",
    "relayhost":"$SMTP_RELAYHOST"
  },

  "run_list": [
    "recipe[chef-server-blueprint::default]",
    "recipe[chef-server::addons]",
    "recipe[rsc_postfix::default]"
  ]
}
EOF

cat <<EOF> $chef_dir/solo.rb
cookbook_path "$chef_dir/cookbooks"
EOF

#cp -f /tmp/environment /etc/environment
/sbin/mkhomedir_helper rightlink

chef-solo -l $LOG_LEVEL -L /var/log/chef.log -j $chef_dir/chef.json \
-c $chef_dir/solo.rb
