#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# ---
# RightScript Name: RS Cluster Init
# Inputs:
#   RS_CLUSTER_NAME:
#     Category: Cluster
#     Description: Cluster name for the cluster. Must be unique per account.
#     Input Type: single
#     Required: true
#     Advanced: false
#   RS_CLUSTER_TYPE:
#     Category: Cluster
#     Description: Cluster type for the cluster.
#     Input Type: single
#     Required: true
#     Advanced: false
#     Possible Values:
#     - text:openshift
#     - text:kubernetes
#   RS_CLUSTER_ROLE:
#     Category: Cluster
#     Input Type: single
#     Required: true
#     Advanced: false
#     Possible Values:
#     - text:master
#     - text:node
#   MY_IP:
#     Category: RightScale
#     Input Type: single
#     Required: true
#     Advanced: true
#     Default: env:PRIVATE_IP
# Attachments:
# - rs_cluster.sh
# ...

# shellcheck source=attachments/rs_cluster.sh
source "$RS_ATTACH_DIR"/rs_cluster.sh

rs_cluster_config
rs_cluster_ssh_key

echo "Setting tags..."
rs_cluster_tag "rs_cluster:ip=$MY_IP"
rs_cluster_tag "rs_cluster:role=$RS_CLUSTER_ROLE"
rs_cluster_tag "rs_cluster:name=$RS_CLUSTER_NAME"
rs_cluster_tag "rs_cluster:type=$RS_CLUSTER_TYPE"
rs_cluster_tag "rs_cluster:ssh_key=$(cat ~/.ssh/id_rsa.pub)"
