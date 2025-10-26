# 루트에서 VPC 모듈 호출
# 변수들은 variables.tf 또는 terraform.tfvar에서 주입

module "vpc" {
  source         = "./modules/vpc"
  name           = "free-tier"
  cidr           = var.vpc_cidr
  azs            = var.vpc_azs
  public_subnets  = var.vpc_public_subnets
  private_subnets = var.vpc_private_subnets
  tags           = var.common_tags
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

