#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

rs_kube_install_prereqs() {
  # Install kubernetes and docker
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
  sudo tee /etc/apt/sources.list.d/kubernetes.list <<EOF
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

  sudo apt-get update

  sudo apt-get install -y docker.io
  sudo apt-get install -y kubelet kubeadm kubectl kubernetes-cni
}

rs_kube_install_master() {
  rs_kube_install_prereqs

  # Initialize the master and save join command
  init_output=$(sudo kubeadm init --pod-network-cidr 10.244.0.0/16)
  echo "$init_output"
  join_command=$(echo "$init_output" | grep -Po "kubeadm join[ .:\w-]+\d")

  # Save the join command as a RightScale credential
  rsc --refreshToken="$RS_REFRESH_TOKEN" --host="$RS_SHARD_HOSTNAME" cm15 create credentials \
    credential[name]="KUBE_${RS_CLUSTER_NAME}_JOIN_CMD" \
    credential[value]="$join_command"

  # Save kubectl configuration
  mkdir -p "$HOME/.kube"
  sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
  sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

  # Initialize core cluster features
  flannel_commit_ref=4bc6cb2208ca2581f6d2a8d77f2b66cb724f9212
  heapster_commit_ref=1308dd71f0ba343895456b46d1bbf3238800b6f3
  kubectl create -f https://raw.githubusercontent.com/coreos/flannel/$flannel_commit_ref/Documentation/kube-flannel-rbac.yml
  kubectl create -f https://raw.githubusercontent.com/coreos/flannel/$flannel_commit_ref/Documentation/kube-flannel.yml
  kubectl create -f https://raw.githubusercontent.com/kubernetes/heapster/$heapster_commit_ref/deploy/kube-config/influxdb/influxdb.yaml
  kubectl create -f https://raw.githubusercontent.com/kubernetes/heapster/$heapster_commit_ref/deploy/kube-config/influxdb/grafana.yaml
  kubectl create -f https://raw.githubusercontent.com/kubernetes/heapster/$heapster_commit_ref/deploy/kube-config/rbac/heapster-rbac.yaml
  kubectl create -f https://raw.githubusercontent.com/kubernetes/heapster/$heapster_commit_ref/deploy/kube-config/influxdb/heapster.yaml
  kubectl create -f https://git.io/kube-dashboard
  
  # Dangerous configuration for demo purposes only
  echo "Request filter disabled, your proxy is vulnerable to XSRF attacks, please be cautious" # default message from kubectl proxy
  echo "This configuration should only be used when incoming traffic is restricted to trusted IP addresses"
  kubectl proxy --disable-filter --address=0.0.0.0 &> /dev/null &
}

rs_kube_install_node() {
  rs_kube_install_prereqs

  # Join cluster
  eval "sudo $KUBE_CLUSTER_JOIN_CMD"
}

rs_kube_install_hello() {
  kubectl apply -f "$RS_ATTACH_DIR/kube_hello.yml"

  hello_port=$(kubectl get svc hello-world -o jsonpath='{.spec.ports[0].nodePort}')

  rs_cluster_tag "rs_cluster:hello_port=$hello_port"
}
