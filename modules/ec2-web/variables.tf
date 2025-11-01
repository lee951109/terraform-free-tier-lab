# 공통
variable "name" {
  description = "리소스 접두사(Name 태그등)"
  type        = string
}

variable "tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}


#네트워크 & SG
variable "vpc_id" {
  description = "대상 VPC ID"
  type        = string
}

variable "public_subnet_id" {
  description = "Web 서버가 배치될 퍼블릭 서브넷 ID "
  type        = string
}

variable "create_security_group" {
  description = "모듈 내부에서 SG 생성 여부(false면 security_group_ids 사용)"
  type        = bool
  default     = true
}

variable "security_group_ids" {
  description = "외부에서 SG 주입 시 사용"
  type        = list(string)
  default     = []
}

variable "http_ingress_cidrs" {
  description = "HTTP(80) 혀용 CIDR 목록"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_ssh" {
  description = "SSH 22포트 허용 여부"
  type        = bool
  default     = false
}

variable "ssh_ingress_cidrs" {
  description = "HTTP(22) 허용 CIDR 목록"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "extra_ingress_rules" {
  description = "추가 인바운드 규칙"
  type = list(object({
    description = optional(string)
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = optional(list(string))
  }))
  default = []
}

#EC2
variable "instance_type" {
  description = "EC2 인스턴스 타입"
  type        = string
  default     = "t2.micro"
}

variable "associate_public_ip" {
  description = "퍼블릭 IP 할당 여부(공개 서브넷 테스트 시 true)"
  type        = bool
  default     = true
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

variable "ami_id" {
  description = "명시적 AMI ID (미지정 시 최신 AL2 자동 탐색)"
  type        = string
  default     = ""
}

variable "param_path_prefix" {
  description = "SSM Parameter Store 경로 prefix(예: /apps/free-tier)"
  type        = string
  default     = "/apps/free-tier" # 빈 값이면 패치 로직이 실패하므로 반드시 채워야함.
}

variable "param_refresh_cron" {
  description = "파라미터 자동 재적용 주지(cron 표현)"
  type        = string
  default     = "*/10 * * * *" #매 10분
}

variable "enable_healthz" {
  description = "/healthz 엔드포인트 활성화 여부"
  type        = bool
  default     = true
}

variable "healthz_path" {
  description = "healthz 경로"
  type        = string
  default     = "/healthz/"
}

variable "render_app_page" {
  description = "index.html 생성 여무"
  type        = bool
  default     = true
}

variable "app_title" {
  description = "index.html <title>"
  type        = string
  default     = "Free-Tier Web"
}



