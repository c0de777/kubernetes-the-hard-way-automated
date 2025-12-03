#!/bin/bash

#placeholder for your public key variable
PUBLIC_KEY=""

# Append public key to known_hosts
echo "$PUBLIC_KEY" >> /home/ec2-user/.ssh/known_hosts

# Set hostname
hostnamectl set-hostname node-0.kubernetes.local

# Permit root login in sshd_config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# Restart sshd to apply changes
systemctl restart sshdstance_type = "t3.micro"

