provider "aws" {
  region = "us-east-1" # change if needed
}

variable "ami_id" {
  default = "ami-0fa3fe0fa7920f68e" # replace with Amazon Linux AMI ID
}

# Jumpbox
resource "aws_instance" "jumpbox" {
  ami           = var.ami_id
  instance_type = "t2.micro"

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "jumpbox"
  }
}

# Kubernetes server
resource "aws_instance" "server" {
  ami           = var.ami_id
  instance_type = "t2.small"

  root_block_device {
    volume_size = 20
  }

  tags = {
    Name = "server"
  }
}

# Worker nodes
resource "aws_instance" "node0" {
  ami           = var.ami_id
  instance_type = "t2.small"

  root_block_device {
    volume_size = 20
  }

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

  tags = {
    Name = "node-1"
  }
}

