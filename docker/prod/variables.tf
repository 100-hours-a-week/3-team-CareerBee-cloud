variable "region" {
  type    = string
  default = "ap-northeast-2"
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
  default = "ami-05a7f3469a7653972" # Ubuntu 22.04 LTS
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

variable "sg_alb_ids" {
  type = list(string)
}

variable "target_group_port" {
  type    = number
  default = 8080
}
