# kubernetes-the-hard-way-automated
utilize terraform to setup initial ec2


1. install terraform [sudo yum install -y yum-utils shadow-utils, sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo, sudo yum install -y terraform]
2. Clone directory into your home directory on your cloudshell enviornment. [ git clone (ssh link) ]
3. configure aws creds for terraform access [aws configure]
4. Configure your public/private keys in /terraform/keys 
5. run main.tf in the terraform folder [terraform init, terraform plan, terraform apply]
6. verify these instances are correct. 

| Name    | Description            | CPU | RAM   | Storage |
|---------|------------------------|-----|-------|---------|
| jumpbox | Administration host    | 1   | 512MB | 10GB    |
| server  | Kubernetes server      | 1   | 2GB   | 20GB    |
| node-0  | Kubernetes worker node | 1   | 2GB   | 20GB    |
| node-1  | Kubernetes worker node | 1   | 2GB   | 20GB    |

