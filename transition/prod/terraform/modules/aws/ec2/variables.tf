variable "ami" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.large" # 2c8m
}

variable "sg_ec2_ids" {
  type = list(any)
}

variable "ebs_type" {
  type = string
}
variable "instance_ebs_size" {
  type = number
}
variable "instance_subnet_id" {
  description = "인스턴스에 사용할 서브넷 ID"
  type        = string
}

variable "associate_public_ip_address" {
  type    = bool
  default = false
}

variable "key_name" {
  type = string
}

variable "db_root_password" {
  type      = string
  sensitive = true
}
