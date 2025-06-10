variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "gcp_project_id" {
  type    = string
  default = "careerbee-prod"
}

variable "gcp_region" {
  type    = string
  default = "asia-northeast3"
}
variable "gcp_zone" {
  type    = string
  default = "asia-northeast3-a"
}
# VPC
variable "azs" {
  type    = list(string)
  default = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "vpc_main_cidr" {
  type    = string
  default = "192.168.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["192.168.10.0/24", "192.168.110.0/24"]
}

variable "private_app_subnet_cidrs" {
  type    = list(string)
  default = ["192.168.20.0/24", "192.168.120.0/24"]
}

variable "private_db_subnet_cidrs" {
  type    = list(string)
  default = ["192.168.30.0/24", "192.168.130.0/24"]
}

# EC2
variable "ami" {
  type    = string
  default = "ami-09194dca7718a360a" # MVP Version
}

variable "db_ami" {
  type    = string
  default = "ami-08943a151bd468f4e" # DB AMI
}

variable "ebs_type" {
  type    = string
  default = "gp2"
}

variable "instance_ebs_size" {
  type    = number
  default = 30
}

variable "key_name" {
  type    = string
  default = "morgan-dev"
}

variable "db_password" {
  type = string
}

# ALB
variable "alb_name" {
  type    = string
  default = "careerbee-prod-alb"
}

variable "target_group_port" {
  type    = number
  default = 8080
}

# VPN
variable "gcp_vpc_cidr_block" {
  type        = string
  description = "CIDR block of the GCP VPC"
  default     = "10.0.0/16" # GCP VPC CIDR 블록
}
