variable "vpc_cidr_block" {
  description = "CIDR_Block for VPC Configuration"
  type        = string
  default     = "10.1.0.0/16"
}

variable "student_name" {
  description = "My name"
  type        = string
  default     = "ruoxi-test"
}

variable "subnet_a_cidr" {
  description = "The CIDR block definition of subnet a"
  type        = string
  default     = "10.1.1.0/24"
}

variable "subnet_b_cidr" {
  description = "The CIDR block definition of subnet b"
  type        = string
  default     = "10.1.2.0/24"
}

variable "subnet_c_cidr" {
  description = "The CIDR block definition of subnet c"
  type        = string
  default     = "10.1.3.0/24"
}

variable "az_1" {
  description = "The first availability zone"
  type        = string
  default     = "us-west-2a"
}

variable "az_2" {
  description = "The second availability zone"
  type        = string
  default     = "us-west-2b"
}

variable "az_3" {
  description = "The third availability zone"
  type        = string
  default     = "us-west-2c"
}

variable "ami_owners" {
  description = "List of AMI owners to filter on."
  type        = list(string)
  default     = ["amazon"]
}

variable "ami_filter_name_key" {
  description = "AMI filter attribute name used to match the AMI name pattern."
  type        = string
  default     = "name"
}

variable "ami_name_pattern" {
  description = "Glob pattern used to match the AL2023 AMI name."
  type        = string
  default     = "al2023-ami-2023.*-x86_64"
}

variable "ami_filter_arch_key" {
  description = "AMI filter attribute name used to match the architecture."
  type        = string
  default     = "architecture"
}

variable "ami_architecture" {
  description = "CPU architecture to filter the AMI on."
  type        = string
  default     = "x86_64"
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "instance_name_tag" {
  description = "Value of the Name tag applied to the EC2 instance."
  type        = string
  default     = "HelloWorld"
}

variable "security_group_name" {
  description = "Name of the security group (also used for its Name tag)."
  type        = string
  default     = "allow_http_ssh"
}

variable "security_group_description" {
  description = "Description of the security group."
  type        = string
  default     = "Allow HTTP & SSH inbound traffic and all outbound traffic"
}

variable "allowed_cidr_ipv4" {
  description = "CIDR block allowed for inbound HTTP/SSH and outbound traffic."
  type        = string
  default     = "0.0.0.0/0"
}

variable "http_port" {
  description = "TCP port used for HTTP ingress."
  type        = number
  default     = 80
}

variable "ssh_port" {
  description = "TCP port used for SSH ingress."
  type        = number
  default     = 22
}

variable "ingress_protocol" {
  description = "IP protocol used for the HTTP and SSH ingress rules."
  type        = string
  default     = "tcp"
}

variable "egress_ip_protocol" {
  description = "IP protocol for the egress rule (-1 = all protocols)."
  type        = string
  default     = "-1"
}

variable "alb_sg_name" {
  description = "Security Group name for the application load balancer"
  type        = string
  default     = "alb-sg"
}

variable "alb_http_port" {
  description = "TCP port used for HTTP ingress for the ALB."
  type        = number
  default     = 80
}

variable "alb_https_port" {
  description = "TCP port used for HTTPS ingress for the ALB."
  type        = number
  default     = 443
}