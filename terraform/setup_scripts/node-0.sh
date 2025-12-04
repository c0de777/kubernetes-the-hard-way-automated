#!/bin/bash

#placeholder for your public key variable
PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC9om4JXfgFhjUagycURjkLGWYy8Pk2aHSB8F1qBCQslZR+aFhU2Pqnmhf3FpImOrkAnGjCflRl5yKk7YtRAxdQ/VHx7ROCFWRdYymHU8Q+OjZHcXgCLhPjRxNS8YM9ViK7DXQSZKNBdtmK68hZBr/GhnOa38AkqXgvda+ar9O1cLf8A42Z1XpY+q8wxK0ubjB9Ag8vzJRG+aOpwJ2dUOSG4YRO8zkz+ymcMl6mmr+DThFfoEjn6xcIyPllF6y5boboQ7fHGZqdYD2jjE9iTz4utpp4+22juuoyRKNfr6k9smM+pvQlCD4oXrOPVsnIGDxDof81ytZzoXccutGNGpEu9eG1ctbiqCL22Ll6MIHQ8w08ZRfY3EnJ4JvaMp8wR8LpgAjErLvDivaqbQtyD1uyn9S3lzx41GmnHdGZYdujCIE29fcLLnhBSbE4XsFCujTgHngrFBM2J1IsQLTNyX8MAJoPzFcE3gEhhz/FFcQSOn0KRWk/yTqCE+52aoqT1sM="

# Append public key to known_hosts
echo "$PUBLIC_KEY" >> /home/ec2-user/.ssh/known_hosts

# Set hostname
hostnamectl set-hostname node-0.kubernetes.local
systemctl restart systemd-hostnamed

# Permit root login in sshd_config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# Restart sshd to apply changes
systemctl restart sshdstance_type = "t3.micro"

