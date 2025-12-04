#!/bin/bash
set -e

# Update and install utilities
apt-get update
apt-get -y install wget curl vim openssl git tar

# Clone Kubernetes The Hard Way repo
git clone --depth 1 https://github.com/kelseyhightower/kubernetes-the-hard-way.git /root/kubernetes-the-hard-way
cd /root/kubernetes-the-hard-way

# Download binaries based on architecture
ARCH=$(dpkg --print-architecture)
wget -q --show-progress --https-only --timestamping -P downloads -i downloads-${ARCH}.txt

# Extract binaries into organized directories
mkdir -p downloads/{client,cni-plugins,controller,worker}
tar -xvf downloads/crictl-v1.32.0-linux-${ARCH}.tar.gz -C downloads/worker/
tar -xvf downloads/containerd-2.1.0-beta.0-linux-${ARCH}.tar.gz --strip-components 1 -C downloads/worker/
tar -xvf downloads/cni-plugins-linux-${ARCH}-v1.6.2.tgz -C downloads/cni-plugins/
tar -xvf downloads/etcd-v3.6.0-rc.3-linux-${ARCH}.tar.gz -C downloads/ --strip-components 1 etcd-v3.6.0-rc.3-linux-${ARCH}/etcdctl etcd-v3.6.0-rc.3-linux-${ARCH}/etcd

mv downloads/{etcdctl,kubectl} downloads/client/
mv downloads/{etcd,kube-apiserver,kube-controller-manager,kube-scheduler} downloads/controller/
mv downloads/{kubelet,kube-proxy} downloads/worker/
mv downloads/runc.${ARCH} downloads/worker/runc

# Clean up archives
rm -rf downloads/*gz

# Make binaries executable
chmod +x downloads/{client,cni-plugins,controller,worker}/*

# Install kubectl
cp downloads/client/kubectl /usr/local/bin/

# Verify installation
kubectl version --client

# --- Create machines.txt with Terraform interpolated values ---
cat <<EOF > /home/ec2-user/machines.txt
${server_private_ip} server.kubernetes.local server
${node0_private_ip} node-0.kubernetes.local node-0 10.200.0.0/24
${node1_private_ip} node-1.kubernetes.local node-1 10.200.1.0/24
EOF

# Write private key for SSH access
mkdir -p /home/ec2-user/.ssh
cat <<EOF >/home/ec2-user/.ssh/id_rsa
${private_key}
EOF
chmod 600 /home/ec2-user/.ssh/id_rsa
chown ec2-user:ec2-user /home/ec2-user/.ssh/id_rsa
