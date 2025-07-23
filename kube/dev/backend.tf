terraform {
  backend "s3" {
    bucket         = "s3-careerbee-dev-infra"
    key            = "tfstate/terraform_kube.tfstate"
    dynamodb_table = "terraform-lock-table"
    region         = "ap-northeast-2"
    encrypt        = true
  }
}