output "nat_instance_id" {
  value       = aws_instance.nat.id
  description = "NAT 인스턴스 ID"
}

output "nat_public_ip" {
  value       = coalesce(try(aws_eip.nat[0].public_ip, null), try(aws_instance.nat.public_ip, null))
  description = "NAT 퍼블릭 IP(EIP가 있으면 EIP)"
}

output "route_ids" {
  value       = [for r in aws_route.private_default_via_nat : r.id]
  description = "프라이빗 기본 라우트 리소스 ID 목록"
}

