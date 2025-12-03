# Provider
provider "aws" {
  region = "us-east-1"
}

# Variables
variable "ami_id" {
  default = "ami-0fa3fe0fa7920f68e" # Amazon Linux AMI ID
}

# --- Networking ---
# Lookup default VPC
data "aws_vpc" "default" {
  default = true
}

# Security Group for Kubernetes cluster
resource "aws_security_group" "k8s_sg" {
  name        = "k8s-sg"
  description = "Allow Kubernetes traffic inside VPC and SSH from my IP"
  vpc_id      = data.aws_vpc.default.id

  # SSH only from your IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["YOUR_PUBLIC_IP/32"] # replace with your IP
  }

  # Kubernetes API server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  # etcd
  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  # kubelet + scheduler + controller
  ingress {
    from_port   = 10250
    to_port     = 10252
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  # read-only kubelet API
  ingress {
    from_port   = 10255
    to_port     = 10255
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  # NodePort services
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-sg"
  }
}

# --- Instances ---
resource "aws_instance" "jumpbox" {
  ami           = var.ami_id
  instance_type = "t2.micro"

  root_block_device {
    volume_size = 10
  }

  vpc_security_group_ids = [aws_security_group.k8s_sg.id]

  tags = {
    Name = "jumpbox"
  }
}

resource "aws_instance" "server" {
  ami           = var.ami_id
  instance_type = "t2.small"

  root_block_device {
    volume_size = 20
  }

  vpc_security_group_ids = [aws_security_group.k8s_sg.id]

  tags = {
    Name = "server"
  }
}

resource "aws_instance" "node0" {
  ami           = var.ami_id
  instance_type = "t2.small"

  root_block_device {
    volume_size = 20
  }

  vpc_security_group_ids = [aws_security_group.k8s_sg.id]

  tags = {
    Name = "node-0"
  }
}

resource "aws_instance" "node1" {
  ami           = var.ami_id
  instance_type = "t2.small"

  root_block_device {
    volume_size = 20
  }

  vpc_security_group_ids = [aws_security_group.k8s_sg.id]

  tags = {
    Name = "node-1"
  }
}
