variable "ami_openvpn" {
  type        = string
  description = "OpenVPN 인스턴스에 사용할 AMI ID"
  default     = "ami-0501c669dc7f0f677" # 예시 AMI ID, 실제 사용 시 변경 필요
}

variable "instance_type" {
  type = string
}

variable "sg_ec2_ids" {
  type = list(any)
}

variable "instance_public_subnet_id" {
  description = "OpenVPN 인스턴스에 사용할 서브넷 ID"
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
