# VPC ID (다른 모듈에서 참조용)
output "vpc_id" {
  value       = aws_vpc.this.id
  description = "VPC_ID"
}

# 퍼블릭 서브넷 ID 리스트 (로드밸런서/EC2 퍼블릭 배치 등)
output "public_subnet_ids" {
  value       = [for s in aws_subnet.public : s.id]
  description = "Public subnet ID list"
}

# 프라이빗 서브넷 ID 리스트 (DB/내부용 EC2 배치 등)
output "private_subnet_ids" {
  value       = [for s in aws_subnet.private : s.id]
  description = "Private subnet ID list"
}

# 퍼블릭 라우트 테이블(필요 시 추가 라우트 연결)
output "public_route_table_id" {
  value       = aws_route_table.public.id
  description = "Public route table ID"
}

# 프라이빗 라우트 테이블(인덱스-> RT ID 매핑)
# NAT 인스턴스 모듈에서 각 RT에 기본 라우트 추가할 때 사용
output "private_route_table_ids" {
  value       = { for k, v in aws_route_table.private : k => v.id }
  description = "Private route table ID mapping (index => RT ID"
}

# IGW ID (디버그/추가 연결 시 활용)
output "igw_id" {
  value       = aws_internet_gateway.this.id
  description = "Internet geteway ID"
}




