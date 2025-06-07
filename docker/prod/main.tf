terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  backend "s3" {
    bucket         = "s3-careerbee-prod-tfstate"  # S3 버킷 이름
    key            = "prod/app/terraform.tfstate" # 버킷 내 tfstate 경로
    region         = "ap-northeast-2"             # 버킷 리전
    dynamodb_table = "ddb-careerbee-prod-tflocks" # 상태 잠금용 DynamoDB 테이블
    encrypt        = true                         # 암호화 사용
  }
}

# AWS VPC
module "vpc" {
  source                   = "../../prod_common/modules/aws/vpc"
  vpc_main_cidr            = var.vpc_main_cidr
  azs                      = var.azs
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
}

data "aws_security_group" "sg_ec2" {
  id = sg-0320ce70d02bd66cf
}

# EC2 
module "ec2" {
  source             = "../../prod_common/modules/aws/ec2"
  instance_type      = "t3.large"
  ebs_type           = var.ebs_type
  instance_ebs_size  = var.instance_ebs_size
  key_name           = var.key_name
  db_root_password   = var.db_password
  sg_ec2_ids         = [data.aws_security_group.sg_ec2.id]
  instance_subnet_id = module.vpc.subnet_private_app[0]
  ami                = var.ami #  AMI (예: AL2023)
  depends_on         = [module.vpc]
}
