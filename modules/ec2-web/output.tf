output "web_instance_id" {
  value       = aws_instance.web.id
  description = "Web EC2 instance ID"
}

output "web_public_ip" {
  value       = aws_instance.web.public_ip
  description = "Web server public ip"
}

output "web_private_ip" {
  value       = aws_instance.web.private_ip
  description = "Web server private ip"
}

output "web_security_group_id" {
  value       = var.create_security_group ? aws_security_group.web[0].id : null
  description = "모듈에서 생성한 SG ID (외부 주입 시 null)"
}




