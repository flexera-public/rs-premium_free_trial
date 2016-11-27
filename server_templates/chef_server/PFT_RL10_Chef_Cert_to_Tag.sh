#! /usr/bin/sudo /bin/bash
# ---
# RightScript Name: PFT RL10 Chef Cert to Tag
# Description: Creates a tag on the server with the value of the Chef SSL
#   Certificate. This is really just used to avoid passing RightScale user
#   credentials to the server, but still extracting the ssl certificate.
#   The tag should be deleted immediatly after use. The format will be
#   chef_server:ssl_cert=<cert material> where <cert material> will have
#   all line returns replaced with ',' and all '=' characters replaced with 'eq;'
# Inputs: {}
# Attachments: []
# ...

set -e

rsc --rl10 cm15 multi_add /api/tags/multi_add resource_hrefs[]=$RS_SELF_HREF "tags[]=chef_server:ssl_cert=`cat /var/opt/opscode/nginx/ca/*.crt | sed ':a;N;$!ba;s/\n/\,/g' | sed 's/=/eq;/g'`"
