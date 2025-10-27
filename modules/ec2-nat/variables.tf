# 리소스 이름 접두사
variable "name" {
  type        = string
  description = "리소스 접두사(Name 태그 등)"
}

# VPC ID (SG 생성용)
variable "vpc_id" {
  type        = string
  description = "대상 VPC ID"
}

# NAT 인스턴스를 배치할 퍼블릭 서브넷 ID( 보통 module.vpc.public_subnet_ids[0])
variable "public_subnet_id" {
  type        = string
  description = "NAT 인스턴스가 위치할 퍼블릭 서브넷 ID"
}

# 프라이빗 라우트 테이블 ID 매핑(인덱스 -> RT ID)
# module.vpc.private_route_table_ids 를 그대로 입력
variable "private_route_table_ids" {
  type        = map(string)
  description = "프라이빗 라우트 테이블 ID 매핑(인덱스→RT ID)"
}

# 인스턴스 타입 (Free Tier: t3.micro 또는 t2.micro)
variable "instance_type" {
  type        = string
  description = "NAT 인스턴스 타입"
  default     = "t3.micro"
}

# (옵션) SSH 접근 허용 CIDR (비우면 SSH 비활성)
variable "ssh_cidr_blocks" {
  type        = list(string)
  description = "SSH 허용 CIDR 목록(비우면 인바운드 생성 안 함)"
  default     = []
}

# (옵션) 고정 퍼블릭 IP를 원하면 EIP 연결
variable "attach_eip" {
  type        = bool
  description = "EIP 연결 여부"
  default     = false
}

# (옵션) 키 페어 이름 (SSH 필요시)
variable "key_name" {
  type        = string
  description = "EC2 Key Pair 이름(선택)"
  default     = ""
}

# (옵션) SSM 관리를 위한 IAM 인스턴스 프로파일 이름
# - 예: EC2RoleForSSM 이나 AmazonSSMManagedInstanceCore가 붙은 프로파일
variable "instance_profile_name" {
  type        = string
  description = "IAM Instance Profile 이름(선택, 비우면 미사용)"
  default     = ""
}

# 공통 태그
variable "tags" {
  type        = map(string)
  description = "공통 태그"
  default     = {}
}
















