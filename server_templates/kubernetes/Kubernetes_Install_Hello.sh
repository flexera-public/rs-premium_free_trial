#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# ---
# RightScript Name: Kubernetes Install Hello
# Inputs: {}
# Attachments:
# - rs_cluster.sh
# - rs_kubernetes.sh
# - kube_hello.yml
# ...

# shellcheck source=attachments/rs_cluster.sh
source "$RS_ATTACH_DIR"/rs_cluster.sh

# shellcheck source=attachments/rs_kubernetes.sh
source "$RS_ATTACH_DIR"/rs_kubernetes.sh

rs_kube_install_hello
