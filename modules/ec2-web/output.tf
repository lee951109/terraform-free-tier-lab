output "web_instance_id" {
  value       = aws_instance.web.id
  description = "Web EC2 instance ID"
}

output "web_public_ip" {
  value       = aws_instance.web.public_ip
  description = "Web server public ip"
}

output "web_sg_id" {
  value       = aws_security_group.web.id
  description = "Web security group ID"
}




