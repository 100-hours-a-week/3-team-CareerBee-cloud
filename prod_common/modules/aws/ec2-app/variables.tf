variable "ami" {
  type = string
}

variable "instance_type" {
  type = string
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

variable "instance_app_subnet_id" {
  description = "App 인스턴스에 사용할 서브넷 ID"
  type        = string
}

variable "app_instance_name" {
  description = "App 인스턴스의 이름"
  type        = string
}
# variable "associate_public_ip_address" {
#   type    = bool
#   default = false
# }

variable "key_name" {
  type = string
}

# variable "eip_allocation_id" {
#   description = "기존 EIP의 allocation ID"
#   type        = string
#   default     = "eipalloc-0e5c2a6433925c012"
# }
