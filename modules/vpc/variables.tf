# 모듈 공통이름 접두사(태그/리소스명에 사용)
variable "name" {
  description = "리소스 공통 접두사(Name 태그 등)"
  type        = string
}

# VPC CIDR (ex: 10.10.0.0/16)
variable "cidr" {
  description = "VPC CIDR"
  type        = string
}

# 사용할 AZ 리스트 (서브넷 인덱스와 매칭; ap-northeast-2a 등)
variable "azs" {
  description = "사용할 가용영역 리스트(서브넷과 인덱스 매칭)"
  type        = list(string)
}

# 퍼블릭 서브넷 CIDR 목록(azs 인덱스와 동일 개수/ 순서)
variable "public_subnets" {
  description = "퍼블릭 서브넷 CIDR 목록 (azs와 인덱스 동일)"
  type        = list(string)
}

# 프라이빗 서브넷 CIDR 목록 (azs인덱스와 동일 개수/순서)
variable "private_subnets" {
  description = "프라이빗 서브넷 CIDR 목록(azs와 인덱스 등일)"
  type        = list(string)
}

# 공통 태그 (프로젝트/비용/소유자등)
variable "tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}

