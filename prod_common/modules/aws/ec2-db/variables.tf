variable "ami_db" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "sg_ec2_ids" {
  type = list(any)
}

variable "instance_db_subnet_id" {
  description = "DB 인스턴스에 사용할 서브넷 ID"
  type        = string
}

variable "db_instance_name" {
  description = "DB 인스턴스의 이름"
  type        = string
}

variable "key_name" {
  type = string
}

variable "ebs_type" {
  type = string
}

variable "instance_ebs_size" {
  type = number
}

variable "db_root_password" {
  type      = string
  sensitive = true
}
