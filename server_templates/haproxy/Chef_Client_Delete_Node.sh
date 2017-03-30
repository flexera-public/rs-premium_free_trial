#! /usr/bin/sudo /bin/bash
# ---
# RightScript Name: Chef Client Delete Node
# Description: Remove the node from the Chef Server.  Run this as a Decommission Script
# Inputs:
#   DELETE_NODE_ON_TERMINATE:
#     Category: CHEF
#     Description: Delete the node from the chef server when the instance is terminated.
#     Input Type: single
#     Required: true
#     Advanced: true
#     Default: text:true
#     Possible Values:
#     - text:true
#     - text:false
# Attachments: []
# ...
set -e

if [ "$DECOM_REASON" == "terminate" ] && [ "$DELETE_NODE_ON_TERMINATE" == "true" ];then
  echo "Removing node ${HOSTNAME} from chef server"
  knife node delete --yes -c /etc/chef/client.rb ${HOSTNAME}
  knife client delete --yes -c /etc/chef/client.rb ${HOSTNAME}
else
  echo "Not terminating, node is not deleted."
  exit 0
fi
