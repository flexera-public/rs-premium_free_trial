#! /usr/bin/sudo /bin/bash
# ---
# RightScript Name: PFT RL10 Chef Validator Pem to Tag
# Description: Creates a tag on the server with the value of the validator key of the
#   specified organization. This is really just used to avoid passing RightScale user
#   credentials to the server, but still extracting the validator key. The tag should
#   be deleted immediatly after use. The format will be chef_org_validator:<orgname>=<key
#   material> where <key material> will have all line returns replaced with ',' and
#   all '=' characters replaced with 'eq;'
# Inputs:
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

rsc --rl10 cm15 multi_add /api/tags/multi_add resource_hrefs[]=$RS_SELF_HREF "tags[]=chef_org_validator:$CHEF_ORG_NAME=`cat /srv/chef-server/orgs/$CHEF_ORG_NAME-validator.pem | sed ':a;N;$!ba;s/\n/\,/g' | sed 's/=/eq;/g'`"
