variable "name" {
  description = "IAM Role/Instance Profile 이름 접두사"
  type        = string
}

variable "ssm_parameter_path_prefix" {
  description = "허용할 SSM 파라미터 경로 prefix(예: /apps/free-tier)"
  type        = string
}

# SecureString을 쓸 경우 KMS Decrypy 허용할 키
variable "kms_key_arns" {
  description = "SecureString 복호화 허용할 KMS 키 ARNs(없으면 ailas/aws/ssm)"
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}



