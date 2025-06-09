# GCP 관련 변수
variable "gcp_project_id" {
  type = string
}

variable "gcp_region" {
  type = string
}

variable "gcp_zone" {
  type = string
}

variable "gcp_credentials_base64" {
  type = string
  sensitive = true
}

variable "gcp_vpc_cidr" {
  type        = string
}

variable "gcp_subnet_cidr" {
  type        = string
}

variable "gcp_ssh_access_cidr_blocks" {
  type    = list(string)
}

variable "gcp_db_access_cidr_blocks" {
  type    = list(string)
}

variable "gcp_static_ip" {
  type = string
}

variable "gcp_service_account_email" {
  type = string
}

# AWS 관련 변수
variable "aws_region" {
  description = "The AWS region"
  type        = string
}

variable "aws_az" {
  description = "AWS 가용 영역"
  type        = string
}

variable "aws_vpc_cidr" {
  description = "AWS VPC CIDR block"
  type        = string
}

variable "aws_subnet_cidr" {
  description = "AWS VPC 서브넷 CIDR"
  type        = string
}

variable "aws_ssh_access_cidr_blocks" {
  type    = list(string)
}

variable "aws_db_access_cidr_blocks" {
  type    = list(string)
}

variable "aws_static_ip" {
  description = "이미 할당된 AWS 고정 IP (EIP)"
  type        = string
}


variable "aws_ubuntu_ami_id" {
  type        = string
  description = "리전에 맞는 Ubuntu 24.04 AMI ID"
}

# 공통
variable "public_key_base64" {
  type = string
}

variable "public_nopass_key_base64" {
  type = string
}

# 환경설정 변수
variable "domain" {}
variable "email" {}
variable "db_name" {}
variable "db_username" {}
variable "db_password" {
  sensitive = true
}
variable "db_url" {
  sensitive = true
}
variable "jwt_secrets" {
  sensitive = true
}
variable "kakao_client_id" {
  sensitive = true
}
variable "kakao_prod_redirect_uri" {
  sensitive = true
}
variable "kakao_dev_redirect_uri" {
  sensitive = true
}
variable "kakao_local_redirect_uri" {
  sensitive = true
}
variable "cookie_domain" {}
variable "sentry_dsn" {
  sensitive = true
}
variable "sentry_auth_token" {
  sensitive = true
}
variable "bucket_backup" {
  sensitive = true
}
variable "bucket_image" {
  sensitive = true
}
variable "bucket_backup_name" {
  sensitive = true
}
variable "bucket_image_name" {
  sensitive = true
}
variable "device_id" {
  sensitive = true
}
variable "mount_dir" {}
variable "deploy_dir" {}
variable "hf_token" {
  type        = string
  sensitive   = true
}
variable "aws_access_key_id" {
  type        = string
  sensitive = true
}
variable "aws_secret_access_key" {
  type        = string
  sensitive   = true
}
variable "aws_default_region" {
  type        = string
}
variable "saramin_secret_key" {
  type        = string
  sensitive   = true
}