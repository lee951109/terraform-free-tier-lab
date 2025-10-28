output "instance_profile_name" {
  value       = aws_iam_instance_profile.this.name
  description = "EC2에 붙일 Instance Profile 이름"
}
