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

    # --- AL2023/AL2 겸용 설치 루틴 ---
    if command -v dnf >/dev/null 2>&1; then
      dnf -y update || true
      dnf -y install nginx jq awscli
    else
      yum update -y
      amazon-linux-extras install nginx1 -y || true
      # AL2에서 extras가 실패한 경우를 대비해 nginx 패키지도 직접 시도
      yum install -y nginx jq awscli || true
    fi

    # Nginx 기동
    systemctl enable --now nginx || systemctl start nginx || true

    # ---------- Parameter Store에서 값 읽기 ----------
    PARAM_PATH="${var.param_path_prefix}"

    mkdir -p /opt/app
    # 아래부터는 Bash 변수이므로 $${...} 로 이스케이프 (Terraform이 건드리지 않게)
    aws ssm get-parameters-by-path \
      --path "$${PARAM_PATH}" \
      --with-decryption \
      --query 'Parameters[].{Name:Name,Value:Value}' \
      --output json > /opt/app/params.json || echo "WARN: SSM fetch failed for $${PARAM_PATH}" >&2

    # 환경파일 생성 (/etc/profile.d/app_env.sh)
    echo "# generated from SSM $${PARAM_PATH}" > /etc/profile.d/app_env.sh

    # jq 루프 내부의 변수들도 모두 $${...} 로
    for row in $(jq -c '.[]' /opt/app/params.json 2>/dev/null || true); do
      NAME=$(echo "$${row}" | jq -r '.Name' | awk -F'/' '{print toupper($$NF)}')
      VAL=$(echo "$${row}" | jq -r '.Value')
      echo "export $${NAME}=\"$${VAL}\"" >> /etc/profile.d/app_env.sh
    done
    chmod 644 /etc/profile.d/app_env.sh || true
    # shellcheck disable=SC1091
    source /etc/profile.d/app_env.sh || true

    # ---------- Nginx index.html에 값 주입 ----------
    # ※ Bash에서 변수 확장 필요하므로 heredoc 구분자에 따옴표를 쓰지 않는다.
    cat >/usr/share/nginx/html/index.html <<HTML
    <html>
      <head><title>Free-Tier Web</title></head>
      <body>
        <h1>Hello from $${APP_NAME}</h1>
        <p>Environment: $${APP_ENV}</p>
        <p>Banner: $${APP_BANNER}</p>
      </body>
    </html>
    HTML

    systemctl reload nginx || true

    # ---------- 재실행용 스크립트(파라미터 재적용) ----------
    # Terraform 치환을 피하려면 이 스크립트에서는 Bash 변수만 쓰고 모두 $${...} 로 표기
    cat >/usr/local/bin/fetch-params.sh <<'SH'
    #!/bin/bash
    set -euxo pipefail

    # 사용법: PARAM_PATH="/apps/free-tier" /usr/local/bin/fetch-params.sh
    : "$${PARAM_PATH:?Set PARAM_PATH environment variable}"

    aws ssm get-parameters-by-path \
      --path "$${PARAM_PATH}" \
      --with-decryption \
      --query 'Parameters[].{Name:Name,Value:Value}' \
      --output json > /opt/app/params.json

    : > /etc/profile.d/app_env.sh
    for row in $(jq -c '.[]' /opt/app/params.json); do
      NAME=$(echo "$${row}" | jq -r '.Name' | awk -F'/' '{print toupper($$NF)}')
      VAL=$(echo "$${row}" | jq -r '.Value')
      echo "export $${NAME}=\"$${VAL}\"" >> /etc/profile.d/app_env.sh
    done
    chmod 644 /etc/profile.d/app_env.sh
    # shellcheck disable=SC1091
    source /etc/profile.d/app_env.sh

    cat >/usr/share/nginx/html/index.html <<HTMLR
    <html>
      <head><title>Free-Tier Web (refreshed)</title></head>
      <body>
        <h1>Hello from $${APP_NAME}</h1>
        <p>Environment: $${APP_ENV}</p>
        <p>Banner: $${APP_BANNER}</p>
      </body>
    </html>
    HTMLR

    systemctl reload nginx
    SH
    chmod +x /usr/local/bin/fetch-params.sh

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


























