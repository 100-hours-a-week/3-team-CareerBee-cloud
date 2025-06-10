# VPC
variable "azs" {
  type        = list(string)
  description = "AZ 리스트 (ex: [\"ap-northeast-2a\", \"ap-northeast-2c\"])"
}

variable "vpc_main_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_app_subnet_cidrs" {
  type = list(string)
}

variable "private_db_subnet_cidrs" {
  type = list(string)
}

# variable "subnet_public_2" {
#   type = string
# }

# variable "subnet_nat_1" {
#   type = string
# }

# variable "subnet_nat_2" {
#   type = string
# }

# variable "subnet_private_1" {
#   type = string
# }

# variable "subnet_private_2" {
#   type = string
# }
