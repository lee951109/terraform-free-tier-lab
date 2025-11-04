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
  count       = var.create_security_group ? 1 : 0
  name        = "${var.name}-web-sg"
  description = "Security group for web server"
  vpc_id      = var.vpc_id

  # inbound Traffic 규칙
  ingress {
    description = "Allow HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.http_ingress_cidrs
  }

  # (옵션) SSH(22) 혀용
  dynamic "ingress" {
    for_each = var.enable_ssh ? [1] : []
    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_ingress_cidrs
    }
  }

  # 추가 인바운드 규칙
  dynamic "ingress" {
    for_each = var.extra_ingress_rules
    content {
      description = lookup(ingress.value, "description", null)
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = lookup(ingress.value, "cidr_blocks", null)
    }
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
    Name = "${var.name}-web-sg",
    Role = "web-sg"
  }, var.tags)
}

# user_data: Nginx 자동설치 및 index.html 배포
locals {
  effective_ami_id = coalesce(try(var.ami_id, null), data.aws_ami.al2.id)

  user_data = templatefile("${path.module}/templates/user_data_web.sh.tftpl", {
    param_path_prefix  = var.param_path_prefix
    enable_healthz     = var.enable_healthz
    healthz_path       = var.healthz_path
    param_refresh_cron = var.param_refresh_cron
    render_app_page    = var.render_app_page
    app_title          = var.app_title
  })
}

# EC2 Web Instance
resource "aws_instance" "web" {
  ami                         = local.effective_ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = var.create_security_group ? [aws_security_group.web[0].id] : var.security_group_ids
  associate_public_ip_address = var.associate_public_ip
  key_name                    = var.key_name != "" ? var.key_name : null
  iam_instance_profile        = var.instance_profile_name != "" ? var.instance_profile_name : null

  user_data = local.user_data

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = merge({
    Name = "${var.name}-web"
    Eenv = "oidc-test"
    Role = "web-server"
  }, var.tags)
}


