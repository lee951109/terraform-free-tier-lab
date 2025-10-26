# VPC CIDR
variable "vpc_cidr" {
  type        = string
  description = "VPC_CIDR"
}

# 사용할 AZ 목록
variable "vpc_azs" {
  type        = list(string)
  description = "availability zone list"
}

# 퍼블릭 서브넷 CIDR
variable "vpc_public_subnets" {
  type        = list(string)
  description = "Public subnet CIDR"
}

# 프라이빗 서브넷 CIDR
variable "vpc_private_subnets" {
  type        = list(string)
  description = "Private subnet CIDR"
}

# 공통 태그
variable "common_tags" {
  type        = map(string)
  description = "Common Tags"
}
