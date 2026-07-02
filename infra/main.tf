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

# Application Load Balancer
resource "aws_lb" "app" {
  name               = "${local.vpc_name}-alb"
  load_balancer_type = "application"
  internal           = false

  security_groups = [aws_security_group.alb.id]

  subnets = [
    aws_subnet.subnets["a"].id,
    aws_subnet.subnets["b"].id,
    aws_subnet.subnets["c"].id
  ]

  tags = {
    Name = "${local.vpc_name}-alb"
  }
}

# ALB security group
resource "aws_security_group" "alb" {
  name        = var.alb_sg_name
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = var.alb_http_port
    to_port     = var.alb_http_port
    protocol    = var.ingress_protocol
    cidr_blocks = [var.allowed_cidr_ipv4]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = var.egress_ip_protocol
    cidr_blocks = [var.allowed_cidr_ipv4]
  }
}

# Target group
resource "aws_lb_target_group" "app" {
  name     = "${local.vpc_name}-tg"
  port     = var.alb_http_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = var.alb_http_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
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

resource "aws_lb_target_group_attachment" "app" {
  for_each = aws_instance.app

  target_group_arn = aws_lb_target_group.app.arn
  target_id        = each.value.id
  port             = var.alb_http_port
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

# Saves the private key locally as a .pem file
resource "local_file" "private_key" {
  content         = tls_private_key.ed25519.private_key_openssh
  filename        = "${path.module}/${var.student_name}-ssh-key.pem"
  file_permission = "0400" # Sets read-only permissions required by SSH
}

# Generate yml directly for Ansible to use

resource "local_file" "ansible_all_vars" {
  filename = "${path.module}/ansible/group_vars/all.yml"

  content = <<EOF
alb_dns: "${aws_lb.app.dns_name}"

ec2_instances:
%{for k, instance in aws_instance.app~}
  ${k}:
    public_ip: "${instance.public_ip}"
    private_ip: "${instance.private_ip}"
%{endfor~}
EOF
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/ansible/inventory.ini"

  content = <<EOF
[web]
%{for name, instance in aws_instance.app~}
${name} ansible_host=${instance.public_ip} ansible_user=ec2-user ansible_ssh_private_key_file=${path.module}/${var.student_name}-ssh-key.pem
%{endfor~}
EOF
}