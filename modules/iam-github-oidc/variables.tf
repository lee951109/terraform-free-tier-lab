############################################################
# 입력 변수 정의
# ----------------------------------------------------------
# 루트 모듈에서 호출 시 전달받을 GitHub 리포 정보, 리전, 리소스 이름 등
############################################################

# GitHub 리포지토리 소유자명 (예: lee951109)
variable "github_owner" {
  description = "GitHub Repository Owner (예: lee951109)"
  type        = string
}

# GitHub 리포지토리 이름 (예: terraform-free-tier-lab)
variable "github_repo" {
  description = "GitHub Repository Name (예: terraform-free-tier-lab)"
  type        = string
}

# OIDC를 허용할 브랜치 (기본: master)
variable "branch" {
  description = "허용할 브랜치 이름 (예: master 또는 main)"
  type        = string
  default     = "master"
}

# 생성할 IAM Role 이름
variable "role_name" {
  description = "GitHub Actions에서 사용할 Terraform IAM Role 이름"
  type        = string
  default     = "gha-terraform-apply-role"
}

# 리전 (Terraform Backend 및 리소스 리전)
variable "region" {
  description = "AWS Region (예: ap-northeast-2)"
  type        = string
  default     = "ap-northeast-2"
}

# Terraform 상태 파일이 저장된 S3 버킷 이름
variable "s3_bucket" {
  description = "Terraform Backend용 S3 Bucket 이름"
  type        = string
}

# Terraform Lock용 DynamoDB 테이블 이름
variable "dynamodb_table" {
  description = "Terraform Backend용 DynamoDB Table 이름"
  type        = string
}

