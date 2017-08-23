#! /usr/bin/sudo /bin/bash
# ---
# RightScript Name: PFT RL10 Chef Credentials
# Description: Creates a credential named 'PFT_LAMP_ChefCert'
# Inputs:
#   REFRESH_TOKEN:
#     Category: Application
#     Description: 'The Rightscale OAUTH refresh token.  Example: cred: MY_REFRESH_TOKEN'
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
#   CHEF_ADMIN_PASSWORD:
#     Category: CHEF
#     Description: Desired password for the Chef administrator user
#     Input Type: single
#     Required: true
#     Advanced: false
#   CHEF_ADMIN_USERNAME:
#     Category: CHEF
#     Description: Chef administrator users username
#     Input Type: single
#     Required: true
#     Advanced: false
# Attachments: []
# ...

# The JQ tool is required, check for it, intall it if it's missing (Ubuntu only)
hasjq=$(which jq)
if [[ $? != 0 ]]
then
  apt-get install -y jq
fi

set -e

source /var/lib/rightscale-identity
rsc_cmd="rsc -a $account -h $api_hostname -r $REFRESH_TOKEN"

create_or_update_cred() {
  found=$($rsc_cmd cm15 index credentials "filter[]=name==$1")

  if [ -z "$found" ]
  then
    echo "No credential with name $1 found, creating it"
    $rsc_cmd cm15 create credentials "credential[value]=$2" "credential[name]=$1"
  else
    echo "Updating credential with name $1"
    href=$(echo $found | jq -r '.[0].links[0].href')
    $rsc_cmd cm15 update $href "credential[value]=$2"
  fi
}

create_or_update_cred "PFT_LAMP_Chef_Admin_Username" $CHEF_ADMIN_USERNAME

# Certificate cred
cert_val=$(cat /var/opt/opscode/nginx/ca/*.crt)
create_or_update_cred "PFT_LAMP_ChefCert" "$cert_val"

# Validator key cred
validator_val=$(cat /srv/chef-server/orgs/$CHEF_ORG_NAME-validator.pem)
create_or_update_cred "PFT_LAMP_ChefValidator" "$validator_val"

# URL cred
public_ip=$(rsc --retry=5 --timeout=60 --rl10 cm15 index_instance_session /api/sessions/instance | jq -r '.public_ip_addresses[0]')
url="https://$public_ip/organizations/$CHEF_ORG_NAME"
create_or_update_cred "PFT_LAMP_ChefUrl" $url
