locals {
  norm = trim(var.path_prefix, "/")
}

# String 파라미터
resource "aws_ssm_parameter" "strings" {
  for_each = var.parameters

  name  = "/${local.norm}/${each.key}"
  type  = "String"
  value = each.value.value
  tags  = var.tags
}

# SecureString 파라미터(선택)
resource "aws_ssm_parameter" "secures" {
  for_each = var.secure_parameters

  name   = "/${local.norm}/${each.key}"
  type   = "SecureString"
  value  = each.value.value
  key_id = try(each.value.key_arn, null)
  tags   = var.tags
}
