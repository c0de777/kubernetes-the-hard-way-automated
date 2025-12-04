#!/bin/bash

# Set hostname
hostnamectl set-hostname server.kubernetes.local
systemctl restart systemd-hostnamed

# Permit root login in sshd_config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# Restart sshd to apply changes
systemctl restart sshdstance_type = "t3.micro"

