variable "name" {
  description = "리소스 접두사(Name 태그등)"
  type        = string
}

variable "vpc_id" {
  description = "대상 VPC ID"
  type        = string
}

variable "public_subnet_id" {
  description = "Web 서버가 배치될 퍼블릭 서브넷 ID "
  type        = string
}

variable "instance_type" {
  description = "EC2 인스턴스 타입"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "SSH 키 페이 이름(옵션)"
  type        = string
  default     = ""
}

variable "instance_profile_name" {
  description = "IAM Instance Profile 이름(옵션)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}

variable "param_path_prefix" {
  description = "SSM Parameter Store 경로 prefix(예: /apps/free-tier)"
  type        = string
  default     = "" # 빈 값이면 패치 로직이 실패하므로 반드시 채워야함.
}

