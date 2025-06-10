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
  id = "sg-0320ce70d02bd66cf"
}

# EC2 - OpenVPN
module "ec2_openvpn" {
  source                    = "../../prod_common/modules/aws/ec2-openvpn"
  instance_public_subnet_id = module.vpc.subnet_public[0]
  instance_type             = "t3.small"
  ebs_type                  = var.ebs_type
  instance_ebs_size         = var.instance_ebs_size
  key_name                  = var.key_name
  sg_ec2_ids                = [data.aws_security_group.sg_ec2.id]
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
  sg_ec2_ids             = [data.aws_security_group.sg_ec2.id]
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
  sg_ec2_ids            = [data.aws_security_group.sg_ec2.id]
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

#VPC - GCP
data "google_compute_network" "gcp_vpc" {
  name    = "vpc-careerbee-ai"
  project = "careerbee-prod"
}

data "google_compute_subnetwork" "gcp_subnet" {
  name    = "subnet-careerbee-ai-private"
  region  = "asia-northeast3"
  project = "careerbee-prod"
}

# VPN
# resource "google_compute_address" "vpn_static_ip_1" {
#   name   = "vpn-static-ip-1"
#   region = "asia-northeast3"
# }

# resource "google_compute_address" "vpn_static_ip_2" {
#   name   = "vpn-static-ip-2"
#   region = "asia-northeast3"
# }

# module "vpn_aws" {
#   source             = "../../prod_common/modules/aws/vpn"
#   vpc_id             = module.vpc.vpc_id
#   gcp_vpc_cidr_block = data.google_compute_subnetwork.gcp_subnet.ip_cidr_range
#   gcp_external_ip_1  = google_compute_address.vpn_static_ip_1.address
#   gcp_external_ip_2  = google_compute_address.vpn_static_ip_2.address
# }

# module "vpn_gcp" {
#   source             = "../../prod_common/modules/gcp/vpn"
#   aws_vpc_cidr_block = module.vpc.vpc_main_cidr
#   gcp_vpc_cidr_block = data.google_compute_subnetwork.gcp_subnet.ip_cidr_range
#   vpn_static_ip_1 = {
#     name    = google_compute_address.vpn_static_ip_1.name
#     region  = google_compute_address.vpn_static_ip_1.region
#     address = google_compute_address.vpn_static_ip_1.address
#   }
#   vpn_static_ip_2 = {
#     name    = google_compute_address.vpn_static_ip_2.name
#     region  = google_compute_address.vpn_static_ip_2.region
#     address = google_compute_address.vpn_static_ip_2.address
#   }
#   aws_external_ip_1 = module.vpn_aws.aws_external_ip_1
#   aws_external_ip_2 = module.vpn_aws.aws_external_ip_2
#   gcp_vpc_self_link = data.google_compute_network.gcp_vpc.self_link
# }
