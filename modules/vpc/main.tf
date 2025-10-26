############################################
# VPC Core (Free Tier Safe: NAT GW 미사용
# - 퍼블릭/ 프라이빗 서브넷, 라우팅 기본 구성
# - 프라이빗 기본 라우트(0.0.0.0/0)는 비워둠
# -> 추후NAT 인스턴스 모튤에서 연결 예정 
############################################

terraform {
  required_version = ">=1.8.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0" # major version 
    }
  }
}

#----- VPC -----
resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_hostnames = true # EC2 내부 DNS 및 Route53사용 편의성 제공
  enable_dns_support   = true # 내부 DNS 쿼리 허용

  # merge(): 두 개 이상의맵(Map)을합치는 함수
  # 기본 Name 태그("my-vpc"등)에 var.tags에서 전달된 사용자 정의 태글르 병합
  tags = merge({
    Name = "${var.name}-vpc" # 기본 태크
  }, var.tags)               # 추가 태그 (예: {Environment = "dev", Owner = "jihyun"}
}

#----- IGW -----
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge({
    Name = "${var.name}-igw"
  }, var.tags)
}

#----- Public Subnet -----
# 각 서브넷은 퍼블릭 IP자동 부여 (map_public_ip_on_launch=true)
# AZ는 azs 목록과 인덱스로 매칭
resource "aws_subnet" "public" {
  for_each = { for idx, cidr in var.public_subnets : idx => cidr }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = var.azs[tonumber(each.key)]
  map_public_ip_on_launch = true

  tags = merge({
    Name = "${var.name}-public-${each.key}"
    Tier = "public"
  }, var.tags)
}

#----- Private Subnet -----
# 인터넷 차단(기본 라우트x)
# NAT 인스턴스 모듈에서 기본 라우트 연결 예정
resource "aws_subnet" "private" {
  for_each = { for idx, cidr in var.private_subnets : idx => cidr }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = var.azs[tonumber(each.key)]

  tags = merge({
    Name = "${var.name}-private-${each.key}"
    Tier = "private"
  }, var.tags)
}

#----- 퍼블릭 라우트 테이블 & 연결 -----
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge({
    Name = "${var.name}-public-rt"
  }, var.tags)
}

# 퍼블릭 RT에 0.0.0.0/0 -> add IGW Route
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

# 모든 퍼블릭 서브넷을 퍼블릭 RT에 연결
resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ----- 프라이빗 라우트 테이블 & 연결 -----
# 현재는 기본 라우트(0.0.0.0/0) 없음 → 인터넷 차단 상태
resource "aws_route_table" "private" {
  for_each = aws_subnet.private

  vpc_id = aws_vpc.this.id
  tags = merge({
    Name = "${var.name}-private-rt-${each.key}"
  }, var.tags)
}

# 각 프라이빗 서브넷에 전용 RT 연결
resource "aws_route_table_association" "private_assoc" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}




























