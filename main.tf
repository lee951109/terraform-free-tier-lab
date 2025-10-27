# -----------------------
# VPC 모듈
# -----------------------
module "vpc" {
  source          = "./modules/vpc"
  name            = "free-tier"
  cidr            = var.vpc_cidr
  azs             = var.vpc_azs
  public_subnets  = var.vpc_public_subnets
  private_subnets = var.vpc_private_subnets
  tags            = var.common_tags
}

# -----------------------
# NAT 인스턴스 모듈
# -----------------------
module "nat" {
  source = "./modules/ec2-nat"

  name                    = "free-tier"
  vpc_id                  = module.vpc.vpc_id
  public_subnet_id        = module.vpc.public_subnet_ids[0]
  private_route_table_ids = module.vpc.private_route_table_ids

  instance_type         = "t3.micro" # 또는 "t2.micro"
  ssh_cidr_blocks       = []         # SSH 안 열기(권장)
  attach_eip            = false      # 퍼블릭 IP 고정 원하면 true
  key_name              = ""         # SSH 필요 시만 입력
  instance_profile_name = ""         # SSM 쓰면 IAM 프로파일명
  tags                  = var.common_tags
}

# -----------------------
# Web 서버 모듈
# -----------------------
module "web" {
  source = "./modules/ec2-web"

  name                  = "free-tier"
  vpc_id                = module.vpc.vpc_id
  public_subnet_id      = module.vpc.public_subnet_ids[0]
  instance_type         = "t3.micro"
  key_name              = "" # SSH 필요시 입력
  instance_profile_name = "" # SSM 사용시 입력
  tags                  = var.common_tags
}

# -----------------------
# 출력(확인용)
# -----------------------
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "nat_instance_id" {
 value = module.nat.nat_instance_id
}

output "nat_public_ip" {
  value = module.nat.nat_public_ip
}

output "web_instance_id" {
  value = module.web.web_instance_id
}
output "web_public_ip" {
  value = module.web.web_public_ip
}

