############################################################
# GitHub OIDC Provider + Terraform 전용 IAM Role 생성 모듈
# ----------------------------------------------------------
# 목적:
#  - GitHub Actions 워크플로우가 AWS에 직접 로그인하지 않고
#    "OIDC(OpenID Connect)"로 안전하게 AssumeRole 하도록 설정
#  - AWS 액세스 키(AccessKey, SecretKey) 없이 Terraform 실행 가능
############################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

############################################################
# GitHub Actions OIDC Provider 생성
# ----------------------------------------------------------
# GitHub이 발급하는 ID 토큰을 AWS가 신뢰하도록 하는 구성요소
# GitHub → AWS 간 "Federation(연합 인증)" 연결의 핵심
############################################################
resource "aws_iam_openid_connect_provider" "github" {
  # GitHub Actions에서 사용하는 OIDC 발급자 URL
  url = "https://token.actions.githubusercontent.com"

  # AWS STS가 허용할 audience 값 (고정: sts.amazonaws.com)
  client_id_list = ["sts.amazonaws.com"]

  # GitHub OIDC의 루트 CA 인증서 핑거프린트
  # (GitHub 공식 문서 기준, 변동 가능)
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]
}

############################################################
# GitHub Actions → AWS AssumeRole Role 생성
# ----------------------------------------------------------
# GitHub 워크플로우가 실행될 때,
# 해당 리포/브랜치의 워크플로우만 Role을 Assume 가능하게 제한
############################################################
resource "aws_iam_role" "gha_terraform" {
  name = var.role_name

  # Assume Role Policy: GitHub OIDC Provider 신뢰 정책
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        # 위에서 만든 OIDC Provider를 신뢰 주체(Federated)로 설정
        Federated = aws_iam_openid_connect_provider.github.arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        # GitHub의 토큰이 AWS STS용으로 발급된 것인지 확인
        StringEquals = {
          "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com"
        },
        # 특정 리포지토리/브랜치만 허용
        StringLike = {
          "token.actions.githubusercontent.com:sub" : [
            # 예시: repo:lee951109/terraform-free-tier-lab:ref:refs/heads/master
            "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/${var.branch}",
            # PR(풀리퀘스트) 빌드도 허용
            "repo:${var.github_owner}/${var.github_repo}:pull_request"
          ]
        }
      }
    }]
  })
}

############################################################
# Role에 Terraform 관련 AWS 권한 부여
# ----------------------------------------------------------
# Terraform이 관리하는 리소스들에 접근할 수 있는 최소 권한 부여
# - S3/DynamoDB: Terraform Backend 접근용
# - EC2/IAM/SSM/CloudWatch: IaC 리소스 생성용
############################################################
data "aws_iam_policy_document" "gha_permissions" {
  # Terraform Backend (S3 + DynamoDB)
  statement {
    sid    = "TerraformBackend"
    effect = "Allow"
    actions = [
      "s3:GetObject", "s3:PutObject", "s3:ListBucket",
      "dynamodb:DescribeTable", "dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:DeleteItem"
    ]
    resources = [
      "arn:aws:s3:::${var.s3_bucket}",
      "arn:aws:s3:::${var.s3_bucket}/*",
      "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.me.account_id}:table/${var.dynamodb_table}"
    ]
  }

  # Terraform이 생성/관리할 리소스들
  statement {
    sid    = "TerraformResources"
    effect = "Allow"
    actions = [
      "ec2:*",       # VPC, Subnet, EC2 등
      "iam:*",       # IAM Role/Policy 관리
      "logs:*",      # CloudWatch Logs 생성
      "ssm:*",       # Parameter Store, Session Manager
      "cloudwatch:*" # CloudWatch Metrics 등
    ]
    resources = ["*"]
  }
}

# 정책 리소스 생성
resource "aws_iam_policy" "gha_policy" {
  name   = "${var.role_name}-policy"
  policy = data.aws_iam_policy_document.gha_permissions.json
}

# Role에 정책 연결
resource "aws_iam_role_policy_attachment" "gha_attach" {
  role       = aws_iam_role.gha_terraform.name
  policy_arn = aws_iam_policy.gha_policy.arn
}

# AWS Account ID 조회 (DynamoDB ARN 생성용)
data "aws_caller_identity" "me" {}

