#!/bin/bash

# Set hostname
hostnamectl set-hostname server.kubernetes.local
systemctl restart systemd-hostnamed

# Permit root login in sshd_config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# Restart sshd to apply changes
systemctl restart sshdstance_type = "t3.micro"

# Wait for jumpbox to finish
while [ ! -f /home/ubuntu/jumpbox.done ]; do
  echo "Waiting for jumpbox to finish cert distribution..."
  sleep 30
done

# --- REST NEEDED ---







# Continue with Kubernetes startup
sudo systemctl start kubelet
sudo systemctl start kube-proxy
