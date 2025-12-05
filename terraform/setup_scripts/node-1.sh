#!/bin/bash
set -e

hostnamectl set-hostname node-1.kubernetes.local
systemctl restart systemd-hostnamed

# Permit root login in sshd_config (optional)
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl restart sshd

# Wait for jumpbox to finish
while [ ! -f /home/ubuntu/jumpbox.done ]; do
  echo "Waiting for jumpbox to finish cert distribution..."
  sleep 30
done

# --- Install OS dependencies ---
sudo apt-get update
sudo apt-get -y install socat conntrack ipset kmod

# --- Create required directories ---
sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

# --- Install worker binaries ---
sudo mv /home/ubuntu/crictl /usr/local/bin/
sudo mv /home/ubuntu/kube-proxy /usr/local/bin/
sudo mv /home/ubuntu/kubelet /usr/local/bin/
sudo mv /home/ubuntu/runc /usr/local/bin/
sudo mv /home/ubuntu/containerd /bin/
sudo mv /home/ubuntu/containerd-shim-runc-v2 /bin/
sudo mv /home/ubuntu/containerd-stress /bin/
sudo mv /home/ubuntu/cni-plugins/* /opt/cni/bin/

# --- Configure CNI networking ---
sudo mv /home/ubuntu/10-bridge.conf /etc/cni/net.d/
sudo mv /home/ubuntu/99-loopback.conf /etc/cni/net.d/
sudo modprobe br-netfilter
echo "br-netfilter" | sudo tee -a /etc/modules-load.d/modules.conf
echo "net.bridge.bridge-nf-call-iptables = 1" | sudo tee -a /etc/sysctl.d/kubernetes.conf
echo "net.bridge.bridge-nf-call-ip6tables = 1" | sudo tee -a /etc/sysctl.d/kubernetes.conf
sudo sysctl -p /etc/sysctl.d/kubernetes.conf

# --- Configure containerd ---
sudo mkdir -p /etc/containerd/
sudo mv /home/ubuntu/containerd-config.toml /etc/containerd/config.toml
sudo mv /home/ubuntu/containerd.service /etc/systemd/system/

# --- Configure kubelet ---
sudo mv /home/ubuntu/kubelet-config.yaml /var/lib/kubelet/
sudo mv /home/ubuntu/kubelet.service /etc/systemd/system/

# --- Configure kube-proxy ---
sudo mv /home/ubuntu/kube-proxy-config.yaml /var/lib/kube-proxy/
sudo mv /home/ubuntu/kube-proxy.service /etc/systemd/system/

# --- Start worker services ---
sudo systemctl daemon-reload
sudo systemctl enable containerd kubelet kube-proxy
sudo systemctl start containerd kubelet kube-proxy
