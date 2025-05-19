terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  backend "s3" {
    bucket         = "s3-careerbee-prod-tfstate"   # S3 버킷 이름
    key            = "prod/app/terraform.tfstate " # 버킷 내 tfstate 경로
    region         = "ap-northeast-2"              # 버킷 리전
    dynamodb_table = "DDB-CAREERBEE-PROD-TFLOCKS"  # 상태 잠금용 DynamoDB 테이블
    encrypt        = true                          # 암호화 사용
  }

}

# AWS VPC
module "vpc" {
  source          = "./modules/aws/vpc"
  vpc_main_cidr   = var.vpc_main_cidr
  subnet_public_1 = var.subnet_public_1
  #   subnet_public_2  = var.subnet_public_2
  #   subnet_nat_1     = var.subnet_nat_1
  #   subnet_nat_2     = var.subnet_nat_2
  #   subnet_private_1 = var.subnet_private_1
  #   subnet_private_2 = var.subnet_private_2
}

# Security Group
resource "aws_security_group" "sg_ec2" {
  vpc_id = module.vpc.vpc_id
  name   = "SG-CAREERBEE-PROD"
  ingress = [
    {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      description      = ""
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]

  egress = [
    {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      description      = ""
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]
}

# EC2 
module "ec2" {
  source             = "./modules/aws/ec2"
  instance_type      = var.instance_type
  ebs_type           = var.ebs_type
  instance_ebs_size  = var.instance_ebs_size
  key_name           = var.key_name
  db_root_password   = var.db_password
  sg_ec2_ids         = [aws_security_group.sg_ec2.id]
  instance_subnet_id = module.vpc.subnet_public_1
  ami                = var.ami #  AMI (예: AL2023)
  depends_on         = [module.vpc]
}
