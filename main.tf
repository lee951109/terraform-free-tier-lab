# -----------------------
# VPC 모듈
# -----------------------
module "vpc" {
  source          = "./modules/vpc"
  name            = "free-tier"
  cidr            = var.vpc_cidr
  azs             = var.vpc_azs
  public_subnets  = var.vpc_public_subnets
  private_subnets = var.vpc_private_subnets
  tags            = var.common_tags
}

# -----------------------
# NAT 인스턴스 모듈
# -----------------------
module "nat" {
  source = "./modules/ec2-nat"

  name                    = "free-tier"
  vpc_id                  = module.vpc.vpc_id
  public_subnet_id        = module.vpc.public_subnet_ids[0]
  private_route_table_ids = module.vpc.private_route_table_ids

  instance_type         = "t3.micro" # 또는 "t2.micro"
  ssh_cidr_blocks       = []         # SSH 안 열기(권장)
  attach_eip            = false      # 퍼블릭 IP 고정 원하면 true
  key_name              = ""         # SSH 필요 시만 입력
  instance_profile_name = ""         # SSM 쓰면 IAM 프로파일명
  tags                  = var.common_tags
}

# -----------------------
# Web 서버 모듈
# -----------------------
module "web" {
  source = "./modules/ec2-web"

  name             = "free-tier"
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnet_ids[0]

  # Free-Tier 외부 curl 점검용 설정
  associate_public_ip   = true
  create_security_group = true
  enable_ssh            = false # SSM만 쓸 거면 false 권장

  # EC2 / IAM
  instance_type = "t2.micro"
  # 인스턴스 프로파일이 있으면 아래 한 줄 유지, 없으면 빈 문자열로 ""
  instance_profile_name = aws_iam_instance_profile.web.name

  # SSM Parameter Store 경로 및 자동재적용 주기
  param_path_prefix  = "/apps/free-tier"
  param_refresh_cron = "*/10 * * * *"

  # 점검 및 페이지 렌더
  enable_healthz  = true
  healthz_path    = "/healthz"
  render_app_page = true
  app_title       = "Free-Tier Web"

  tags = var.common_tags
}

# -----------------------
# IAM (최소 권한 예시)
# -----------------------
data "aws_iam_policy_document" "web_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "web" {
  name               = "free-tier-web-role"
  assume_role_policy = data.aws_iam_policy_document.web_assume.json
  tags               = var.common_tags
}

# SSM Parameter Store & (옵션) KMS Decrypt
data "aws_iam_policy_document" "web_inline" {
  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:DescribeParameters",
    ]
    resources = ["*"] # 데모: 와일드카드. 운영은 경로/KMS 키로 최소화
  }

  # 암호화 파라미터 사용 시 KMS 추가
  statement {
    actions   = ["kms:Decrypt"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:EncryptionContextKeys"
      values   = ["aws:ssm:parameter-name"]
    }
  }
}

resource "aws_iam_role_policy" "web_inline" {
  name   = "free-tier-web-ssm"
  role   = aws_iam_role.web.id
  policy = data.aws_iam_policy_document.web_inline.json
}

resource "aws_iam_instance_profile" "web" {
  name = "free-tier-web-instance-profile"
  role = aws_iam_role.web.name
  tags = var.common_tags
}

# --------------------------------------------------------------------
# SSM Session Manager 권한 정책 추가 (EC2에서 SSM 접속 가능하도록)
# --------------------------------------------------------------------
data "aws_iam_policy_document" "web_ssm" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:UpdateInstanceInformation",
      "ssm:DescribeInstanceInformation",
      "ssm:SendCommand",
      "ssm:StartSession",
      "ssm:ResumeSession",
      "ssm:TerminateSession",
      "ec2messages:*",
      "ssmmessages:*"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "web_ssm" {
  name   = "free-tier-web-ssm-session"
  role   = aws_iam_role.web.id
  policy = data.aws_iam_policy_document.web_ssm.json
}

# -----------------------
# GitHub Action
# -----------------------
module "iam_github_oidc" {
  source = "./modules/iam-github-oidc"

  github_owner   = "lee951109"
  github_repo    = "terraform-free-tier-lab"
  branch         = "master"
  s3_bucket      = "free-tier-lab-tfstate-buket"
  dynamodb_table = "tfstate-lock"
}

# -----------------------
# 출력(확인용)
# -----------------------
output "vpc_id" {
  value = module.vpc.vpc_id
}
output "nat_instance_id" {
  value = module.nat.nat_instance_id
}
output "nat_public_ip" {
  value = module.nat.nat_public_ip
}
output "web_instance_id" {
  value = module.web.web_instance_id
}
output "web_public_ip" {
  value = module.web.web_public_ip
}
