#!/bin/bash

rs_kube_install_master() {
  # Download kubernetes and docker
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

  sudo tee /etc/apt/sources.list.d/kubernetes.list <<EOF
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

  sudo apt-get update

  sudo apt-get install -y docker.io
  sudo apt-get install -y kubelet kubeadm kubectl kubernetes-cni

  # Initialize the master
  token=$(sudo kubeadm init --pod-network-cidr 10.244.0.0/16 | tail -n 1)

  # Save the token as a RightScale credential
  rsc --refreshToken="$RS_REFRESH_TOKEN" --host="$RS_SHARD_HOSTNAME" cm15 create credentials \
    credential[name]="KUBE_${RS_CLUSTER_NAME}_CLUSTER_TOKEN" \
    credential[value]="$token"

  # Initialize the overlay network
  sudo kubectl apply -f "$RS_ATTACH_DIR/kube_flannel.yml"
  sudo kubectl apply -f "$RS_ATTACH_DIR/kube_dashboard.yml"
  sudo kubectl apply -f "$RS_ATTACH_DIR/kube_influxdb.yml"

  dashboard_port=$(sudo kubectl get svc -n kube-system | grep '^kubernetes-dashboard ' | awk '{print $4}' | cut -f1 -d/ | cut -f2 -d:)

  rs_cluster_tag "rs_cluster:dashboard_port=$dashboard_port"
}

rs_kube_install_node() {
  # Download kubernetes and docker
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
  sudo tee /etc/apt/sources.list.d/kubernetes.list <<EOF
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

  sudo apt-get update

  sudo apt-get install -y docker.io
  sudo apt-get install -y kubelet kubeadm kubectl kubernetes-cni

  # Join cluster
  eval "sudo $KUBE_CLUSTER_JOIN_CMD"
}

rs_kube_install_hello() {
  sudo kubectl apply -f "$RS_ATTACH_DIR/kube_hello.yml"

  hello_port=$(sudo kubectl get svc -n default | grep '^hello-world ' | awk '{print $4}' | cut -f1 -d/ | cut -f2 -d:)

  rs_cluster_tag "rs_cluster:hello_port=$hello_port"
}
