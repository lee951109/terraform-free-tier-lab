terraform {
 backend "s3" {
  bucket = "free-tier-lab-tfstate-buket"
  key = "dev/terraform.tfstste"
  region = "ap-northeast-2"
  dynamodb_table = "tfstate-lock"
  encrypt = true
 }
}
