# Provider
provider "aws" {
  region = "us-east-1"
}

# Variables
variable "ami_id" {
  default = "ami-0ecb62995f68bb549" # Replace with Amazon Linux or Debian AMI ID
}

# --- Networking ---
# Lookup default VPC automatically
data "aws_vpc" "default" {
  default = true
}

# Security Group (SSH + Kubernetes ports)
resource "aws_security_group" "k8s_sg" {
  name        = "k8s-sg"
  description = "Allow SSH from anywhere and Kubernetes traffic inside VPC"
  vpc_id      = data.aws_vpc.default.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

# --- Key Pair ---
resource "aws_key_pair" "main" {
  key_name   = "k8s-key"
  public_key = file("${path.module}/keys/k8shard.pub")
}

# --- Instances ---
resource "aws_instance" "server" {
  ami           = var.ami_id
  instance_type = "t2.small"
  key_name      = aws_key_pair.main.key_name

  root_block_device {
    volume_size = 20
  }

  vpc_security_group_ids = [aws_security_group.k8s_sg.id]

  # Run server setup script
  user_data = file("${path.module}/setup_scripts/server.sh")

  tags = {
    Name = "server"
  }
}

resource "aws_instance" "node0" {
  ami           = var.ami_id
  instance_type = "t2.small"
  key_name      = aws_key_pair.main.key_name

  root_block_device {
    volume_size = 20
  }

  vpc_security_group_ids = [aws_security_group.k8s_sg.id]

  # Run node-0 setup script
  user_data = file("${path.module}/setup_scripts/node-0.sh")

  tags = {
    Name = "node-0"
  }
}

resource "aws_instance" "node1" {
  ami           = var.ami_id
  instance_type = "t2.small"
  key_name      = aws_key_pair.main.key_name

  root_block_device {
    volume_size = 20
  }

  vpc_security_group_ids = [aws_security_group.k8s_sg.id]

  # Run node-1 setup script
  user_data = file("${path.module}/setup_scripts/node-1.sh")

  tags = {
    Name = "node-1"
  }
}

resource "aws_instance" "jumpbox" {
  ami           = var.ami_id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.main.key_name

  root_block_device {
    volume_size = 10
  }

  vpc_security_group_ids = [aws_security_group.k8s_sg.id]

  # Use templatefile so we can inject IPs and private key into jumpbox.sh
  user_data = templatefile("${path.module}/setup_scripts/jumpbox.sh", {
    server_private_ip = aws_instance.server.private_ip
    node0_private_ip  = aws_instance.node0.private_ip
    node1_private_ip  = aws_instance.node1.private_ip
    private_key       = file("${path.module}/keys/k8shard.pem")   # path to your private key file
  })

  # Ensure jumpbox is created after server and nodes
  depends_on = [
    aws_instance.server,
    aws_instance.node0,
    aws_instance.node1
  ]

  tags = {
    Name = "jumpbox"
  }
}
