output "path_prefix" {
  value       = "/${trim(var.path_prefix, "/")}"
  description = "생성된 파라미터 경로 prefix"
}

output "parameter_arns" {
  value       = [for p in aws_ssm_parameter.strings : p.arn]
  description = "String 파라미터 ARNs"
}

output "secure_parameter_arns" {
  value       = [for p in aws_ssm_parameter.secures : p.arn]
  description = "SecureString 파라미터 ARNs"
}
