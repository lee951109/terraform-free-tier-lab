#############################################
# EC2 Web Server Module (Free Tier Safe)
# - 퍼블릭 서브넷에 배포
# - Nginx 자동 설치 및 간단한 index.html 생성
#############################################

terraform {
  required_version = ">= 1.8.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# 최신 Amazon Linux 2 AMI 조회
data "aws_ami" "al2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# 보안그룹: HTTP 허용
resource "aws_security_group" "web" {
  name        = "${var.name}-web-sg"
  description = "Security group for web server"
  vpc_id      = var.vpc_id

  # inbound Traffic 규칙
  ingress {
    description = "Allow HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound Traffic 규칙
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    Name = "${var.name}-web-sg"
  }, var.tags)
}

# user_data: Nginx 자동설치 및 index.html 배포
locals {
  web_user_data = <<-EOT
    #!/bin/bash
    set -euxo pipefail
    yum update -y
    amazon-linux-extras install nginx1 -y
    systemctl enable nginx
    echo "<h1>Hello from Terraform Web Server</h1>" > /usr/share/nginx/html/index.html
    systemctl start nginx
  EOT
}

# EC2 Web Instance
resource "aws_instance" "web" {
  ami                         = data.aws_ami.al2.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true
  key_name                    = var.key_name != "" ? var.key_name : null
  iam_instance_profile        = var.instance_profile_name != "" ? var.instance_profile_name : null

  user_data = local.web_user_data

  tags = merge({
    Name = "${var.name}-web"
    Role = "web-server"
  }, var.tags)
}


























