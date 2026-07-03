#Create a new vpc
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name      = "tf-asb-flow-${var.student_name}"
    ManagedBy = "Terraform"
  }
}

# Create 3 subnets
locals {
  vpc_name = "tf-asb-flow-${var.student_name}"
  subnets = {
    a = {
      cidr = var.subnet_a_cidr
      az   = var.az_1
    }
    b = {
      cidr = var.subnet_b_cidr
      az   = var.az_2
    }
    c = {
      cidr = var.subnet_c_cidr
      az   = var.az_3
    }
  }
}

resource "aws_subnet" "subnets" {
  for_each = local.subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.vpc_name}-subnet-${each.key}"
  }
}

# Create IGW
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.vpc_name}-igw"
  }
}

# Create a route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${local.vpc_name}-public-rt"
  }
}

# Associate 3 subnets
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.subnets

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# aws_image
data "aws_ami" "al2023" {
  most_recent = true
  owners      = var.ami_owners

  filter {
    name   = var.ami_filter_name_key
    values = [var.ami_name_pattern]
  }

  filter {
    name   = var.ami_filter_arch_key
    values = [var.ami_architecture]
  }
}

# ec2 instance 
resource "aws_instance" "app" {
  for_each = aws_subnet.subnets

  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = each.value.id
  key_name               = aws_key_pair.my_key.key_name
  vpc_security_group_ids = [aws_security_group.allow_http_ssh.id]

  user_data = <<-EOF
    #!/bin/bash
    yum install -y httpd
    systemctl start httpd
    echo "Hello from ${each.key}" > /var/www/html/index.html
  EOF

  tags = {
    Name = "${local.vpc_name}-app-${each.key}"
  }
}

# aws_security_group
resource "aws_security_group" "allow_http_ssh" {
  name        = var.security_group_name
  description = var.security_group_description
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = var.security_group_name
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.allow_http_ssh.id
  cidr_ipv4         = var.allowed_cidr_ipv4
  from_port         = var.http_port
  ip_protocol       = var.ingress_protocol
  to_port           = var.http_port
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ipv4" {
  security_group_id = aws_security_group.allow_http_ssh.id
  cidr_ipv4         = var.allowed_cidr_ipv4
  from_port         = var.ssh_port
  ip_protocol       = var.ingress_protocol
  to_port           = var.ssh_port
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_http_ssh.id
  cidr_ipv4         = var.allowed_cidr_ipv4
  ip_protocol       = var.egress_ip_protocol # semantically equivalent to all ports
}

# Generates a secure private key
resource "tls_private_key" "ed25519" {
  algorithm = "ED25519"
}

# Registers the public key with AWS
resource "aws_key_pair" "my_key" {
  key_name   = "${var.student_name}-ssh-key"
  public_key = tls_private_key.ed25519.public_key_openssh
}

# Saves the private key locally as a .pem file (in ansible folder)
resource "local_file" "private_key" {
  content         = tls_private_key.ed25519.private_key_openssh
  filename        = "${path.module}/../ansible/${var.student_name}-ssh-key.pem"
  file_permission = "0400" # Sets read-only permissions required by SSH
}

# Generate the Ansible inventory directly from the instances

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory.ini"

  content = <<EOF
[web]
%{for name, instance in aws_instance.app~}
${name} ansible_host=${instance.public_ip} ansible_user=ec2-user ansible_ssh_private_key_file=./${var.student_name}-ssh-key.pem
%{endfor~}
EOF
}