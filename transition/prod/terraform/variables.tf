variable "region" {
  type    = string
  default = "ap-northeast-2"
}

# VPC
variable "vpc_main_cidr" {
  type    = string
  default = "192.168.0.0/16"
}

variable "subnet_public_1" {
  type    = string
  default = "192.168.10.0/24"
}

# variable "subnet_public_2" {
#   type    = string
#   default = "192.168.110.0/24"
# }

# variable "subnet_nat_1" {
#   type    = string
#   default = "192.168.20.0/24"
# }

# variable "subnet_nat_2" {
#   type    = string
#   default = "192.168.120.0/24"
# }

# variable "subnet_private_1" {
#   type    = string
#   default = "192.168.30.0/24"
# }

# variable "subnet_private_2" {
#   type    = string
#   default = "192.168.130.0/24"
# }

# EC2
variable "ami" {
  type    = string
  default = "ami-05a7f3469a7653972" # Ubuntu 22.04 LTS
}

variable "instance_type" {
  type    = string
  default = "t3.large"

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
# variable "openvpn_password" {
#   type = string
#   # sensitive = true
# }

# RDS
# variable "dbname" {
#   type    = string
#   default = "morgan-dev"
# }

# variable "engine" {
#   type    = string
#   default = "mysql"
# }

# variable "db_password" {
#   type      = string
#   sensitive = true
# }

# variable "sg_allow_ingress_list_mysql" {
#   type    = list(any)
#   default = []
# }

# variable "rds_instance_count" {
#   type    = number
#   default = 1
# }

# variable "rds_instance_class" {
#   type    = string
#   default = "db.t3.micro"
# }

#  ALB
# variable "port" {
#   type    = number
#   default = 8080
# }

# # variable "aws_s3_lb_logs_name" {
# #   type    = string
# #   default = "morgan-dev-alb-logs"
# # }

variable "availability_zone" {
  type    = string
  default = "ap-northeast-2a"

}

# SSM
# variable "rds_db_url" {
#   type = string
# }

# variable "rds_db_name" {
#   type = string
# }

# variable "rds_db_username" {
#   type = string
# }

# variable "rds_db_password" {
#   type = string
# }

