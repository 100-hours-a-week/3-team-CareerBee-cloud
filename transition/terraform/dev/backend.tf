terraform {
  backend "s3" {
    bucket         = var.bucket_backup
    key            = "terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
  }
}