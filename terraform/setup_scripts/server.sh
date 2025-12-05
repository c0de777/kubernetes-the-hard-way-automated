#!/bin/bash
set -e

# Set hostname
hostnamectl set-hostname server.kubernetes.local
systemctl restart systemd-hostnamed

# Permit root login in sshd_config (optional)
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl restart sshd

# Wait for jumpbox to finish
while [ ! -f /home/ubuntu/jumpbox.done ]; do
  echo "Waiting for jumpbox to finish cert distribution..."
  sleep 30
done

# --- Install the etcd binaries ---
sudo mv /home/ubuntu/etcd /usr/local/bin/
sudo mv /home/ubuntu/etcdctl /usr/local/bin/

# --- Configure the etcd server ---
sudo mkdir -p /etc/etcd /var/lib/etcd
sudo chmod 700 /var/lib/etcd
sudo cp /home/ubuntu/ca.crt /home/ubuntu/kube-api-server.key /home/ubuntu/kube-api-server.crt /etc/etcd/

# --- Install the etcd systemd unit file ---
sudo mv /home/ubuntu/etcd.service /etc/systemd/system/

# --- Start the etcd server ---
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd

# --- Create the Kubernetes configuration directory ---
sudo mkdir -p /etc/kubernetes/config

# --- Install the Kubernetes controller binaries ---
sudo mv /home/ubuntu/kube-apiserver /usr/local/bin/
sudo mv /home/ubuntu/kube-controller-manager /usr/local/bin/
sudo mv /home/ubuntu/kube-scheduler /usr/local/bin/
sudo mv /home/ubuntu/kubectl /usr/local/bin/

# --- Configure the Kubernetes API server ---
sudo mkdir -p /var/lib/kubernetes/
sudo mv /home/ubuntu/ca.crt /home/ubuntu/ca.key \
  /home/ubuntu/kube-api-server.key /home/ubuntu/kube-api-server.crt \
  /home/ubuntu/service-accounts.key /home/ubuntu/service-accounts.crt \
  /home/ubuntu/encryption-config.yaml \
  /var/lib/kubernetes/

# --- Install the kube-apiserver systemd unit file ---
sudo mv /home/ubuntu/kube-apiserver.service /etc/systemd/system/kube-apiserver.service

# --- Configure the Kubernetes Controller Manager ---
sudo mv /home/ubuntu/kube-controller-manager.kubeconfig /var/lib/kubernetes/
sudo mv /home/ubuntu/kube-controller-manager.service /etc/systemd/system/

# --- Configure the Kubernetes Scheduler ---
sudo mv /home/ubuntu/kube-scheduler.kubeconfig /var/lib/kubernetes/
sudo mv /home/ubuntu/kube-scheduler.yaml /etc/kubernetes/config/
sudo mv /home/ubuntu/kube-scheduler.service /etc/systemd/system/

# --- Start the controller services ---
sudo systemctl daemon-reload
sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler

# --- Apply RBAC config for API server to talk to kubelet ---
kubectl apply -f /home/ubuntu/kube-apiserver-to-kubelet.yaml \
  --kubeconfig /home/ubuntu/admin.kubeconfig
