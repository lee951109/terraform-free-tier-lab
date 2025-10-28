variable "path_prefix" {
  description = "SSM 파라미터 경로 prefix(예: /apps/free-tire)"
  type        = string
}

variable "parameters" {
  description = "생성할 파라미터 목록(string기준;SecureString은 별도 옵션 사용)"
  type = map(object({
    value = string
  }))
  default = {
    "app_name"   = { value = "FreeTierLab" }
    "app_env"    = { value = "dev" }
    "app_banner" = { value = "Hello from parameter store" }
  }
}

# SecureString 예제
variable "secure_parameters" {
  description = "민감정보 (SecureString) - 실제 운영 시 KMS키와 함께 사용"
  type = map(object({
    value   = string
    key_arn = optional(string) # 비우면 AWS 관리형 KMS(alias/aws/ssm)
  }))
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
