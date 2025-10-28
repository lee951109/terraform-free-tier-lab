data "aws_iam_policy_document" "assume_ec2" {

  # statement는 하나의 정책 명령 단위
  statement {
    # statement가 허용(Allow)인지 거부(Dney)인지를 명시
    effect = "Allow"

    # 누가(어떤 서비스나 계정이) 이 Role을 맏을 수 있는지 지정
    principals {
      type = "Service"
      # 실제 서비스 식별자를 나열
      identifiers = ["ec2.amazonaws.com"]
    }
    # 허용할 구체적인 액션을 지정
    # EC2 인스턴스가 IAM Role을 맡기 위해 사용하는 액션이 "sts:AssumeRole"
    # 즉, EC2가 STS(Security Token Service)를 통해 임시 자격 증명을 얻어 Role 권한을 사용할 수 있게 됨.
    actions = ["sts:AssumeRole"]
  }
}

# EC2 역할
resource "aws_iam_role" "this" {
  name               = "${var.name}-ec2-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
  tags               = var.tags
}

# SSM 에이전트/Session Manager용 AWS 관리형 정책
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.this.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Parameter Store 읽기 최소권한 (해당 prefix만 허용)
data "aws_iam_policy_document" "param_read" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:aws:ssm:*:*:parameter${var.ssm_parameter_path_prefix}",
      "arn:aws:ssm:*:*:parameter${var.ssm_parameter_path_prefix}/*"
    ]
  }

  # SecureString 복호화가 필요하면 KMS Decrypt 허용
  dynamic "statement" {
    for_each = length(var.kms_key_arns) > 0 ? [1] : []
    content {
      effect    = "Allow"
      actions   = ["kms:Decrypt"]
      resources = var.kms_key_arns
    }
  }
}

resource "aws_iam_policy" "param_read" {
  name   = "${var.name}-ssm-param-read"
  policy = data.aws_iam_policy_document.param_read.json
}

resource "aws_iam_role_policy_attachment" "param_read" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.param_read.arn
}

# Instance Profile
resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-ec2-ssm-profile"
  role = aws_iam_role.this.name
}

