terraform {
  backend "s3" {
    bucket         = "s3-careerbee-dev-tfstate"
    key            = "dev/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
  }
}