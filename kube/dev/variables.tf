# 공통
variable "vpn_shared_secret" {
  type      = string
  sensitive = true
}

variable "prefix" {
  type = string
}

variable "public_nopass_key_base64" {
  type      = string
  sensitive = true
}

variable "ssmu_access_cidr_blocks" {
  type = list(string)
}

variable "github_url" {
  type = string
}

variable "github_token" {
  type      = string
  sensitive = true
}

variable "ssh_key_base64_nopass" {
  type      = string
  sensitive = true
}

variable "argocd_admin_password_hash" {
  type      = string
  sensitive = true
}

###########################################################################################################################################

# AWS

variable "aws_region" {
  type = string
}

variable "aws_azone_az" {
  type = string
}
variable "aws_czone_az" {
  type = string
}

variable "aws_access_key_id" {
  type      = string
  sensitive = true
}
variable "aws_secret_access_key" {
  type        = string
  sensitive   = true
}

variable "aws_static_ip" {
  type = string
}

variable "aws_vpc_cidr" {
  type = string
}
variable "aws_public_subnet_azone_cidr" {
  type = string
}
variable "aws_public_subnet_czone_cidr" {
  type = string
}

variable "aws_private_subnet_1" {
  type = string
}
variable "aws_private_subnet_2" {
  type = string
}
variable "aws_private_subnet_3" {
  type = string
}
variable "aws_private_subnet_4" {
  type = string
}

variable "aws_master_azone_private_ip" {
  type = string
}
variable "aws_worker_service_azone_private_ip" {
  type = string
}
variable "aws_worker_db_azone_private_ip" {
  type = string
}
variable "aws_argocd_azone_private_ip" {
  type = string
}

variable "openvpn_pw" {
  type      = string
  sensitive = true
}

###########################################################################################################################################

# GCP

variable "gcp_project_id" {
  type = string
}

variable "gcp_region" {
  type = string
}

variable "gcp_az" {
  type = string
}

variable "gcp_credentials_base64" {
  type      = string
  sensitive = true
}

variable "gcp_vpc_cidr" {
  type = string
}
variable "gcp_public_subnet_cidr" {
  type = string
}
variable "gcp_private_subnet_cidr" {
  type = string
}
variable "gcp_gce_private_ip" {
  type = string
}

variable "gcp_service_account_email" {
  type = string
}

