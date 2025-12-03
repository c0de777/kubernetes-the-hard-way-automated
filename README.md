# kubernetes-the-hard-way-automated
utilize terraform to setup initial ec2


1. install terraform [sudo yum install -y yum-utils shadow-utils, sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo, sudo yum install -y terraform]
2. Clone directory into your home directory on your cloudshell enviornment. [ git clone (ssh link) ]
3. configure aws creds for terraform access [aws configure]
4. run main.tf in the terraform folder [terraform init, terraform plan, terraform apply]
5. verify these instances are correct. 
