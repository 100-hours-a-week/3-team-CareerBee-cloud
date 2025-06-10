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

# EC2 공통 보안 그룹 (APP, VPN 포함)
resource "aws_security_group" "sg_ec2_common" {
  name   = "SG-careerbee-prod-ec2-common"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["211.244.225.166/32"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["211.244.225.166/32"]
  }

  ingress {
    from_port   = 6100
    to_port     = 6100
    protocol    = "tcp"
    cidr_blocks = ["211.244.225.166/32"]
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["211.244.225.166/32", "15.164.51.95/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG-careerbee-prod-ec2-common"
  }
}

# App 보안 그룹
resource "aws_security_group" "sg_ec2_app" {
  name        = "SG-careerbee-prod-ec2-app"
  description = "Allow HTTP/HTTPS from all, SSH from fixed IP"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH from office IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["211.244.225.166/32"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG-careerbee-prod-ec2-app"
  }
}

# DB 보안 그룹
resource "aws_security_group" "sg_db" {
  name   = "SG-careerbee-prod-db"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_ec2_common.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["211.244.225.166/32"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG-careerbee-prod-db"
  }
}

# EC2 - OpenVPN
module "ec2_openvpn" {
  source                    = "../../prod_common/modules/aws/ec2-openvpn"
  instance_public_subnet_id = module.vpc.subnet_public[0]
  instance_type             = "t3.small"
  ebs_type                  = var.ebs_type
  instance_ebs_size         = var.instance_ebs_size
  key_name                  = var.key_name
  sg_ec2_ids                = [aws_security_group.sg_ec2_common.id]
  depends_on                = [module.vpc]

}
# EC2 - APP
module "ec2_app" {
  count                  = 2
  source                 = "../../prod_common/modules/aws/ec2-app"
  instance_type          = "t3.large"
  ebs_type               = var.ebs_type
  instance_ebs_size      = var.instance_ebs_size
  key_name               = var.key_name
  sg_ec2_ids             = [aws_security_group.sg_ec2_app.id]
  instance_app_subnet_id = module.vpc.subnet_private_app[count.index]
  ami                    = var.ami #  AMI 
  app_instance_name      = "ec2-careerbee-prod-app-${module.vpc.azs[count.index]}"
  depends_on             = [module.vpc]
}

# EC2 - DB
module "ec2_db" {
  count                 = 2
  source                = "../../prod_common/modules/aws/ec2-db"
  db_root_password      = var.db_password
  instance_type         = "t3.medium"
  ebs_type              = var.ebs_type
  instance_ebs_size     = var.instance_ebs_size
  key_name              = var.key_name
  sg_ec2_ids            = [aws_security_group.sg_db.id]
  instance_db_subnet_id = module.vpc.subnet_private_db[count.index]
  ami_db                = var.db_ami
  db_instance_name      = "ec2-careerbee-prod-db-${module.vpc.azs[count.index]}"
  depends_on            = [module.vpc]
}
# ALB - Security Group
resource "aws_security_group" "sg_alb" {
  vpc_id = module.vpc.vpc_id
  name   = "SG-careerbee-prod-alb"

  ingress = [
    {
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      description      = "Allow HTTP"
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
      description      = "Allow All Outbound"
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]

  tags = {
    Name = "SG-careerbee-prod-alb"
  }
}

# ALB
module "alb" {
  source            = "../../prod_common/modules/aws/loadbalancer"
  alb_name          = var.alb_name
  sg_alb_ids        = [aws_security_group.sg_alb.id]
  subnet_ids        = module.vpc.subnet_public
  target_group_port = var.target_group_port
  vpc_id            = module.vpc.vpc_id
}

