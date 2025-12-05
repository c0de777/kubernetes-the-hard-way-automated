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

# --- Generate kubeconfigs for worker nodes ---
for host in node-0 node-1; do
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://server.kubernetes.local:6443 \
    --kubeconfig=$${host}.kubeconfig

  kubectl config set-credentials system:node:$${FQDN} \
    --client-certificate=$${host}.crt \
    --client-key=$${host}.key \
    --embed-certs=true \
    --kubeconfig=$${host}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:$${FQDN} \
    --kubeconfig=$${host}.kubeconfig

  kubectl config use-context default \
    --kubeconfig=$${host}.kubeconfig
done

# --- kube proxy gen ---
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://server.kubernetes.local:6443 \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config set-credentials system:kube-proxy \
    --client-certificate=kube-proxy.crt \
    --client-key=kube-proxy.key \
    --embed-certs=true \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-proxy \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config use-context default \
    --kubeconfig=kube-proxy.kubeconfig
}

# --- kube controller gen ---
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://server.kubernetes.local:6443 \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=kube-controller-manager.crt \
    --client-key=kube-controller-manager.key \
    --embed-certs=true \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-controller-manager \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config use-context default \
    --kubeconfig=kube-controller-manager.kubeconfig
}

# --- kube scheduler config gen ---
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://server.kubernetes.local:6443 \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-credentials system:kube-scheduler \
    --client-certificate=kube-scheduler.crt \
    --client-key=kube-scheduler.key \
    --embed-certs=true \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-scheduler \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config use-context default \
    --kubeconfig=kube-scheduler.kubeconfig
}

# --- admin kube gen ---
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=admin.kubeconfig

  kubectl config set-credentials admin \
    --client-certificate=admin.crt \
    --client-key=admin.key \
    --embed-certs=true \
    --kubeconfig=admin.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=admin \
    --kubeconfig=admin.kubeconfig

  kubectl config use-context default \
    --kubeconfig=admin.kubeconfig
}

# --- Distribute kubeconfigs to worker nodes ---
for host in node-0 node-1; do
  # Create required directories
  ssh -i /home/ubuntu/.ssh/k8shard.pem ubuntu@$${host} "sudo mkdir -p /var/lib/kube-proxy"
  ssh -i /home/ubuntu/.ssh/k8shard.pem ubuntu@$${host} "sudo mkdir -p /var/lib/kubelet"

  # Copy kube-proxy kubeconfig
  scp -i /home/ubuntu/.ssh/k8shard.pem kube-proxy.kubeconfig \
    ubuntu@$${host}:/home/ubuntu/kube-proxy.kubeconfig
  ssh -i /home/ubuntu/.ssh/k8shard.pem ubuntu@$${host} "sudo mv /home/ubuntu/kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig"

  # Copy kubelet kubeconfig
  scp -i /home/ubuntu/.ssh/k8shard.pem $${host}.kubeconfig \
    ubuntu@$${host}:/home/ubuntu/kubelet.kubeconfig
  ssh -i /home/ubuntu/.ssh/k8shard.pem ubuntu@$${host} "sudo mv /home/ubuntu/kubelet.kubeconfig /var/lib/kubelet/kubeconfig"
done

# --- Generate an encryption key ---
export ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

# --- Create the encryption-config.yaml file ---
envsubst < configs/encryption-config.yaml \
  > encryption-config.yaml

# --- Copy the encryption-config.yaml file to the controller instance ---
scp -i /home/ubuntu/.ssh/k8shard.pem encryption-config.yaml ubuntu@server:/home/ubuntu/
ssh -i /home/ubuntu/.ssh/k8shard.pem ubuntu@server "sudo mv /home/ubuntu/encryption-config.yaml /etc/kubernetes/"
