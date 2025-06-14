terraform {
  backend "s3" {
    bucket         = "s3-careerbee-dev-infra"
    key            = "tfstate/terraform_docker.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
  }
}