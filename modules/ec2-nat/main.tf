#############################################
# EC2 NAT Instance (Free Tier Safe)
# - 퍼블릭 서브넷에 NAT 인스턴스 1대
# - IP 포워딩 + iptables SNAT
# - 프라이빗 RT 기본 라우트(0.0.0.0/0) → NAT 인스턴스
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

# 최신 Amazon Linux 2 x86_64 (gp2) AMI 조회
# - iptables 기반 예시를 위해 Amazon Linux 2 사용
data "aws_ami" "al2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# NAT 인스턴스 보안그룹
# - 아웃바운드: 전체 허용 (프라이빗에서 나가는 트래픽 NAT)
# - 인바운드: 기본 차단, SSH 허용을 원할 때만 CIDR로 열기
resource "aws_security_group" "nat" {
  name        = "${var.name}-nat-sg"
  description = "Security group for NAT instance"
  vpc_id      = var.vpc_id

  # 아웃바운드(egress) 트래픽 허용 규칙
  egress {
    description      = "Allow all egress"
    from_port        = 0    # all port (0 ~ 65535)
    to_port          = 0    # all port (0 ~ 65535)
    protocol         = "-1" # all protocol(TCP,UDP,ICMP등)
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = [] # not allow
  }

  tags = merge({
    Name = "${var.name}-nat-sg"
  }, var.tags)
}

# SSH 허용(옵션): cidr_blocks가 비어있지 않을 때만 생성
resource "aws_vpc_security_group_ingress_rule" "nat_ssh" {
  count = length(var.ssh_cidr_blocks) > 0 ? 1 : 0

  security_group_id = aws_security_group.nat.id
  description       = "Optional SSH access to NAT instance"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.ssh_cidr_blocks[0] #필요 시 목록 확장 가능
}

# (옵션) SSM으로 관리하고 싶다면, IAM 인스턴스 프로파일을 전달
# - var.instance_profile_name 이 비어있지 않으면 프로파일 연결
locals {
  iam_instance_profile = var.instance_profile_name != "" ? var.instance_profile_name : null
}

# NAT 인스턴스 사용자 데이터
# - IP 포워딩 활성화
# - iptables NAT(MASQUERADE) 설정 및 영구화
# - Amazon Linux 2 기준 (iptables-services 사용)
locals {
  nat_user_data = <<-EOT
    #!/bin/bash
    # e: 에러 발생 시 즉시 종료,
    # u: 선언되지 않은 변수 사용 시 에러
    # o pipefail: 파이프라인 중간 단계 에러도 전파
    set -euo pipefail # 초기 부팅 단계라 실패를 조기에 감지하기 위함

    # Enable IP forwarding: 리눅스가 라우터처럼 패킷을 넘기려면 필요
    sysctl -w net.ipv4.ip_forward=1
    sed -i 's/^#\\?net.ipv4.ip_forward=.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf

    # Disable ICMP redirects (권장): 라우팅 혼선,보안 리스크 줄이기 위함
    sysctl -w net.ipv4.conf.all.send_redirects=0
    sysctl -w net.ipv4.conf.default.send_redirects=0

    # Install iptables-services for persistence
    yum install -y iptables-services

    # Flush and set NAT (SNAT) on eth0
    # 기존 filter/nat 테이블 룰 초기화후,
    # SNAT 규칙: eth0로 나가는 트래픽의 출발지 IP를 NAT 인스턴스의 퍼블릭 IP로 변경
    iptables -F
    iptables -t nat -F
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

    # Save rules and enable service
    service iptables save
    systemctl enable iptables

    # Basic hardening: allow established/related, allow from private subnets, drop rest
    iptables -P FORWARD DROP
    iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
    # 허용할 프라이빗 CIDR들 추가(루트 변수에서 넘어온 값 사용 불가 → 보안그룹/라우팅으로 제어)
    # 필요 시 추가 로직 작성 가능
  EOT
}

# NAT 인스턴스 (퍼블릭 서브넷에 배치)
resource "aws_instance" "nat" {
  ami                         = data.aws_ami.al2.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.nat.id]
  associate_public_ip_address = true
  source_dest_check           = false # NAT 필수
  key_name                    = var.key_name != "" ? var.key_name : null
  iam_instance_profile        = local.iam_instance_profile

  user_data = local.nat_user_data

  tags = merge({
    Name = "${var.name}-nat"
    Role = "nat-instance"
  }, var.tags)
}

# (옵션) EIP 연결: 퍼블릭 IP를 고정하고 싶을 때
# 현재 사용하지 않을 예졍. 
resource "aws_eip" "nat" {
  count    = var.attach_eip ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.nat.id

  tags = merge({
    Name = "${var.name}-nat-eip"
  }, var.tags)
}

# 프라이빗 라우트 테이블에 기본 라우트(0.0.0.0/0) 추가
# - 대상: NAT 인스턴스
resource "aws_route" "private_default_via_nat" {
  for_each               = var.private_route_table_ids
  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat.primary_network_interface_id
}


























