variable "gcp_external_ip_1" {
  description = "GCP VPN Gateway의 외부 IP 주소"
  type        = string
}

variable "gcp_external_ip_2" {
  description = "GCP VPN Gateway의 외부 IP 주소"
  type        = string
}

variable "vpc_id" {
  description = "AWS VPC ID"
  type        = string
}

variable "gcp_vpc_cidr_block" {
  description = "GCP VPC CIDR 블록"
  type        = string

}

variable "shared_secret_1" {
  description = "Shared secret for the first VPN tunnel"
  type        = string
  default     = "vpn_shared_key_test_1"
}

variable "shared_secret_2" {
  description = "Shared secret for the first VPN tunnel"
  type        = string
  default     = "vpn_shared_key_test_2"
}
