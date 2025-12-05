#!/bin/bash
set -e

# Set hostname
hostnamectl set-hostname server.kubernetes.local
systemctl restart systemd-hostnamed

# Permit root login in sshd_config (optional)
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# Restart sshd to apply changes
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

# --- Install the systemd unit file ---
sudo mv /home/ubuntu/etcd.service /etc/systemd/system/

# --- Start the etcd server ---
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd
