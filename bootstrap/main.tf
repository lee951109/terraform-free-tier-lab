provider "aws" {
  region = "ap-northeast-2"
}

resource "aws_s3_bucket" "tfstate" {
  bucket = "free-tier-lab-tfstate-buket"

  tags = {
    Name   = "free-tier-lab-tfstate-bucket"
    Projet = "terraform-free-tier-lab"
    Stage  = "dev"
  }
}

# 퍼블릭 차단
resource "aws_s3_bucket_public_acess_block" "tfstate" {
  bucket                  = aws_s3_bukect.tfstate.id
  block_public_acls       = true # Access Control List 차단
  block_public_policy     = true # 퍼블릭 버킷 정책 차단
  ignore_public_acls      = true # 기존의 퍼블릭 ACL이 있더라도 무시
  restrict_public_buckets = true # 퍼블릭 버킷 전체를 완전히 차단
}

# 서버사이드 암호화(AES256)
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Disabled" # Free Tier 비용 고려, 버저닝 끔
  }
}

resource "aws_dynamodb_table" "lock" {
  name         = "tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
