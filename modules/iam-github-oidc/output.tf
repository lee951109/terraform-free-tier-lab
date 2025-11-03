############################################################
# 출력 변수 정의
# ----------------------------------------------------------
# 루트 모듈에서 이 모듈 호출 시 참조 가능한 값들
# (예: Role ARN을 GitHub Actions 워크플로우에 입력)
############################################################

# GitHub OIDC Provider ARN
output "oidc_provider_arn" {
  description = "GitHub OIDC Provider의 ARN (AWS 콘솔에서 확인용)"
  value       = aws_iam_openid_connect_provider.github.arn
}

# Terraform에서 사용할 IAM Role ARN
output "role_arn" {
  description = "GitHub Actions가 Assume할 IAM Role ARN"
  value       = aws_iam_role.gha_terraform.arn
}

