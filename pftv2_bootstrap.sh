#!/usr/bin/env bash

# TODO: test and publish them
if [[ "$*" == *"help"* ]]
then
  echo "Usage: pftv2_bootstrap.sh [options]"
  echo "  options:"
  echo "    all - Does bootstrapping of all following items. This is the default if no option is set"
  echo "    cats - Upserts all libraries and application cats"
  echo "    sts - Upserts all ServerTemplates"
  echo "    management - Launches management CATs for creating networks, MCI, and STs"
  echo "    creds - Upserts the PFT_RS_REFRESH_TOKEN credential with the value provided in OAUTH_REFRESH_TOKEN"
fi

options="all"
if [[ -n "$*" ]]
then
  options=$*
fi

if [[ -z "$OAUTH_REFRESH_TOKEN" || -z "$ACCOUNT_ID" || -z "$SHARD_HOSTNAME" ]]
then
  echo "The following environment variables must be set. OAUTH_REFRESH_TOKEN, ACCOUNT_ID, SHARD_HOSTNAME"
  exit 1
fi

cat_list_file="pftv2_cat_list-us.txt"
echo "Checking for regional mapping, used to decide which pftv2_cat_list-<REGIONAL_MAPPING>.txt CAT list to use"
if [[ -z "$REGIONAL_MAPPING" ]]
then
  echo "The environment variable REGIONAL_MAPPING was not set, so it will be set to 'us' by default."
else
  cat_list_file="pftv2_cat_list-$REGIONAL_MAPPING.txt"
  echo "The environment variable REGIONAL_MAPPING was set to $REGIONAL_MAPPING. Checking for file $cat_list_file..."

  if [[ ! -e "$cat_list_file" ]]
  then
    echo "CAT list file - $cat_list_file not found."
    exit 1
  fi
fi


export RIGHT_ST_LOGIN_ACCOUNT_ID=$ACCOUNT_ID
export RIGHT_ST_LOGIN_ACCOUNT_HOST=$SHARD_HOSTNAME
export RIGHT_ST_LOGIN_ACCOUNT_REFRESH_TOKEN=$OAUTH_REFRESH_TOKEN

hasrsc=$(which rsc)
if [[ $? != 0 ]]
then
  echo "The binary 'rsc' must be installed - https://github.com/rightscale/rsc"
  exit 1
fi

hasjq=$(which jq)
if [[ $? != 0 ]]
then
  echo "The binary 'jq' must be installed - https://stedolan.github.io/jq/"
  exit 1
fi

hasrightst=$(which right_st)
if [[ $? != 0 ]]
then
  echo "The binary 'right_st' must be installed - https://github.com/rightscale/right_st"
  exit 1
fi

# Requires parameters.
# 1) The name of the management CAT to launch
management_cat_launch_wait_terminate_delete() {
  echo "Searching for management CAT template by name ($1)..."
  network_template_href=$(rsc -r $OAUTH_REFRESH_TOKEN -a $ACCOUNT_ID -h $SHARD_HOSTNAME ss index /api/designer/collections/$ACCOUNT_ID/templates "filter[]=name==$1" --x1=.href)
  echo "Found ($1) template at href $network_template_href. Launching CloudApp..."
  network_cloud_app_href=$(rsc -r $OAUTH_REFRESH_TOKEN -a $ACCOUNT_ID -h $SHARD_HOSTNAME ss create /api/manager/projects/$ACCOUNT_ID/executions "name=$1 - Bootstrap" "template_href=$network_template_href" --xh=Location)
  echo "CloudApp for template ($1) launched with execution href - $network_cloud_app_href. Waiting for completion..."
  status="unknown"
  while [[ "$status" != "running" && "$status" != "failed" ]]
  do
    status=$(rsc -r $OAUTH_REFRESH_TOKEN -a $ACCOUNT_ID -h $SHARD_HOSTNAME ss show $network_cloud_app_href --x1=.status)
    if [[ "$status" != "running" && "$status" != "failed" ]]
    then
      echo "CloudApp is $status. Waiting 20 seconds before checking again..."
      sleep 20
    else
      break
    fi
  done

  if [[ "$status" == "failed" ]]
  then
    echo "WARNING: The management CAT named ($1) failed. We'll continue with other stuff, but you should probably check it out. It won't be automatically terminated."
  else
    echo "Terminating ($1) CloudApp..."
    terminate=$(rsc -r $OAUTH_REFRESH_TOKEN -a $ACCOUNT_ID -h $SHARD_HOSTNAME ss terminate $network_cloud_app_href)
    status="unknown"
    while [[ "$status" != "terminated" && "$status" != "failed" ]]
    do
      status=$(rsc -r $OAUTH_REFRESH_TOKEN -a $ACCOUNT_ID -h $SHARD_HOSTNAME ss show $network_cloud_app_href --x1=.status)
      if [[ "$status" != "terminated" && "$status" != "failed" ]]
      then
        echo "CloudApp is $status. Waiting 20 seconds before checking again..."
        sleep 20
      else
        break
      fi
    done
    echo "Deleting ($1) CloudApp..."
    delete=$(rsc -r $OAUTH_REFRESH_TOKEN -a $ACCOUNT_ID -h $SHARD_HOSTNAME ss delete $network_cloud_app_href)
  fi
}

if [[ "$options" == *"all"* || "$options" == *"cats"* ]]
then
  echo "Upserting CAT and library files."
  for i in `cat $cat_list_file`
  do
    cat_name=$(sed -n -e "s/^name[[:space:]]['\"]*\(.*\)['\"]/\1/p" $i)
    echo "Checking to see if ($cat_name - $i) has already been uploaded..."
    cat_href=$(rsc -r $OAUTH_REFRESH_TOKEN -a $ACCOUNT_ID -h $SHARD_HOSTNAME ss index collections/$ACCOUNT_ID/templates "filter[]=name==$cat_name" | jq -r '.[0].href')
    if [[ -z "$cat_href" ]]
    then
      echo "($cat_name - $i) not already uploaded, creating it now..."
      rsc -r $OAUTH_REFRESH_TOKEN -a $ACCOUNT_ID -h $SHARD_HOSTNAME ss create collections/$ACCOUNT_ID/templates source=$i
    else
      echo "($cat_name - $i) already uploaded, updating it now..."
      rsc -r $OAUTH_REFRESH_TOKEN -a $ACCOUNT_ID -h $SHARD_HOSTNAME ss update $cat_href source=$i
    fi
  done
else
  echo "Skipping CAT and library upsert."
fi

if [[ "$options" == *"all"* || "$options" == *"management"* ]]
then
  echo "Launching management CATs."

  management_cat_launch_wait_terminate_delete "PFT Admin CAT - PFT Network Setup"
  management_cat_launch_wait_terminate_delete "PFT Admin CAT - PFT Base Linux MCI Setup/Maintenance"
  management_cat_launch_wait_terminate_delete "PFT Admin CAT - PFT Base Linux ServerTemplate Setup/Maintenance"
  management_cat_launch_wait_terminate_delete "PFT Admin CAT - PFT LAMP ServerTemplates Prerequisite Import"
else
  echo "Skipping management CATs."
fi

if [[ "$options" == *"all"* || "$options" == *"sts"* ]]
then
  echo "Upserting ServerTemplates."
  right_st st upload server_templates/chef_server/*.yml
  right_st st upload server_templates/haproxy-chef12/*.yml
  right_st st upload server_templates/mysql-chef12/*.yml
  right_st st upload server_templates/php-chef12/*.yml
else
  echo "Skipping ServerTemplates."
fi

if [[ "$options" == *"all"* || "$options" == *"creds"* ]]
then
  echo "Upserting Credentials."
  existing=$(rsc -r $OAUTH_REFRESH_TOKEN -a $ACCOUNT_ID -h $SHARD_HOSTNAME cm15 index credentials "filter[]=name==PFT_RS_REFRESH_TOKEN")
  if [[ -z "$existing" ]]
  then
    echo "PFT_RS_REFRESH_TOKEN Credential does not exist, creating it..."
    rsc -r $OAUTH_REFRESH_TOKEN -a $ACCOUNT_ID -h $SHARD_HOSTNAME cm15 create credentials "credential[name]=PFT_RS_REFRESH_TOKEN" "credential[value]=$OAUTH_REFRESH_TOKEN"
  else
    echo "PFT_RS_REFRESH_TOKEN Credential already existed, updating it..."
    existing_href=$(echo $existing | jq -r ".[0].links[].href")
    rsc -r $OAUTH_REFRESH_TOKEN -a $ACCOUNT_ID -h $SHARD_HOSTNAME cm15 update $existing_href "credential[value]=$OAUTH_REFRESH_TOKEN"
  fi
else
  echo "Skipping Credentials."
fi
