variable "aws_external_ip_1" {
  description = "AWS VPN Gateway의 외부 IP 주소"
  type        = string
}

variable "aws_external_ip_2" {
  description = "AWS VPN Gateway의 외부 IP 주소"
  type        = string
}

variable "shared_secret_1" {
  description = "Shared secret for the first VPN tunnel"
  type        = string
  default     = "vpn_shared_key_test_1"
}

variable "shared_secret_2" {
  description = "Shared secret for the second VPN tunnel"
  type        = string
  default     = "vpn_shared_key_test_2"
}

variable "aws_vpc_cidr_block" {
  description = "AWS VPC CIDR block"
  type        = string
}

variable "gcp_vpc_cidr_block" {
  description = "CIDR block of the GCP VPC"
  type        = string
}

variable "vpn_static_ip_1" {
  description = "Static IP for the first VPN tunnel"
  type = object({
    name    = string
    region  = string
    address = string
  })
}

variable "vpn_static_ip_2" {
  description = "Static IP for the first VPN tunnel"
  type = object({
    name    = string
    region  = string
    address = string
  })
}

variable "gcp_vpc_self_link" {
  description = "Self link of the GCP VPC"
  type        = string
}
