#!/bin/bash
set -e

# Update and install utilities
apt-get update
apt-get -y install wget curl vim openssl git tar

# Set hostname
hostnamectl set-hostname jumpbox.kubernetes.local

# Clone Kubernetes The Hard Way repo
git clone --depth 1 https://github.com/kelseyhightower/kubernetes-the-hard-way.git /root/kubernetes-the-hard-way
cd /root/kubernetes-the-hard-way

# Download binaries based on architecture
ARCH=$(dpkg --print-architecture)
wget -q --show-progress --https-only --timestamping -P downloads -i downloads-$${ARCH}.txt

# Extract binaries into organized directories
mkdir -p downloads/{client,cni-plugins,controller,worker}
tar -xvf downloads/crictl-v1.32.0-linux-$${ARCH}.tar.gz -C downloads/worker/
tar -xvf downloads/containerd-2.1.0-beta.0-linux-$${ARCH}.tar.gz --strip-components 1 -C downloads/worker/
tar -xvf downloads/cni-plugins-linux-$${ARCH}-v1.6.2.tgz -C downloads/cni-plugins/
tar -xvf downloads/etcd-v3.6.0-rc.3-linux-$${ARCH}.tar.gz -C downloads/ --strip-components 1 etcd-v3.6.0-rc.3-linux-$${ARCH}/etcdctl etcd-v3.6.0-rc.3-linux-$${ARCH}/etcd

mv downloads/{etcdctl,kubectl} downloads/client/
mv downloads/{etcd,kube-apiserver,kube-controller-manager,kube-scheduler} downloads/controller/
mv downloads/{kubelet,kube-proxy} downloads/worker/
mv downloads/runc.$${ARCH} downloads/worker/runc

# Clean up archives
rm -rf downloads/*gz

# Make binaries executable
chmod +x downloads/{client,cni-plugins,controller,worker}/*

# Install kubectl
cp downloads/client/kubectl /usr/local/bin/

# Verify installation
kubectl version --client

# Configure SSH to skip host key checking for automation
cat <<EOF >/etc/ssh/ssh_config.d/99-nohostkey.conf
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF

# --- Create machines.txt with Terraform interpolated values ---
cat <<EOF > /home/ubuntu/machines.txt
${server_private_ip} server.kubernetes.local server
${node0_private_ip} node-0.kubernetes.local node-0 10.200.0.0/24
${node1_private_ip} node-1.kubernetes.local node-1 10.200.1.0/24
EOF

# --- Generate hosts file from machines.txt ---
cd /home/ubuntu
echo "" > hosts
echo "# Kubernetes The Hard Way Automated" >> hosts

while read IP FQDN HOST SUBNET; do
    ENTRY="$${IP} $${FQDN} $${HOST}"
    echo $ENTRY >> hosts
done < machines.txt

# --- Append to /etc/hosts ---
cat hosts >> /etc/hosts

# Write private key for SSH access
mkdir -p /home/ubuntu/.ssh
cat <<EOF >/home/ubuntu/.ssh/k8shard.pem
${private_key}
EOF
chmod 600 /home/ubuntu/.ssh/k8shard.pem
chown ubuntu:ubuntu /home/ubuntu/.ssh/k8shard.pem

# --- Distribute hosts file to all cluster members ---
while read IP FQDN HOST SUBNET; do
  scp -i /home/ubuntu/.ssh/k8shard.pem hosts ubuntu@$${HOST}:~/
  ssh -i /home/ubuntu/.ssh/k8shard.pem ubuntu@$${HOST} "sudo sh -c 'cat hosts >> /etc/hosts'"
done < machines.txt

# --- Certificate generation and distribution ---
{
  openssl genrsa -out ca.key 4096
  openssl req -x509 -new -sha512 -noenc \
    -key ca.key -days 3653 \
    -config ca.conf \
    -out ca.crt
}

certs=(
  "admin" "node-0" "node-1"
  "kube-proxy" "kube-scheduler"
  "kube-controller-manager"
  "kube-api-server"
  "service-accounts"
)

for i in $${certs[*]}; do
  openssl genrsa -out "$${i}.key" 4096

  openssl req -new -key "$${i}.key" -sha256 \
    -config "ca.conf" -section $${i} \
    -out "$${i}.csr"

  openssl x509 -req -days 3653 -in "$${i}.csr" \
    -copy_extensions copyall \
    -sha256 -CA "ca.crt" \
    -CAkey "ca.key" \
    -CAcreateserial \
    -out "$${i}.crt"
done

for host in node-0 node-1; do
  ssh -i /home/ubuntu/.ssh/k8shard.pem ubuntu@$${host} "sudo mkdir -p /var/lib/kubelet/"

  scp -i /home/ubuntu/.ssh/k8shard.pem ca.crt ubuntu@$${host}:/home/ubuntu/
  ssh -i /home/ubuntu/.ssh/k8shard.pem ubuntu@$${host} "sudo mv /home/ubuntu/ca.crt /var/lib/kubelet/"

  scp -i /home/ubuntu/.ssh/k8shard.pem $${host}.crt ubuntu@$${host}:/home/ubuntu/kubelet.crt
  ssh -i /home/ubuntu/.ssh/k8shard.pem ubuntu@$${host} "sudo mv /home/ubuntu/kubelet.crt /var/lib/kubelet/"

  scp -i /home/ubuntu/.ssh/k8shard.pem $${host}.key ubuntu@$${host}:/home/ubuntu/kubelet.key
  ssh -i /home/ubuntu/.ssh/k8shard.pem ubuntu@$${host} "sudo mv /home/ubuntu/kubelet.key /var/lib/kubelet/"
done

scp -i /home/ubuntu/.ssh/k8shard.pem \
  ca.key ca.crt \
  kube-api-server.key kube-api-server.crt \
  service-accounts.key service-accounts.crt \
  
