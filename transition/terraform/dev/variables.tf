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

variable "gcp_credentials_file" {
  type = string
}

variable "gcp_vpc_cidr" {
  description = "GCP VPC CIDR block"
  type        = string
}

variable "gcp_subnet_cidr" {
  description = "GCP VPC 서브넷 CIDR"
  type        = string
}

variable "gcp_db_access_cidr_blocks" {
  type    = list(string)
}

variable "gcp_static_ip" {
  type = string
}

variable "gcp_public_key_path" {
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

variable "aws_credentials_file" {
  description = "Path to AWS credentials JSON file"
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

variable "aws_db_access_cidr_blocks" {
  type    = list(string)
}

variable "aws_static_ip" {
  description = "이미 할당된 AWS 고정 IP (EIP)"
  type        = string
}

variable "aws_public_key_path" {
  description = "SSH 공개 키 경로"
  type        = string
}

variable "aws_ubuntu_ami_id" {
  type        = string
  description = "리전에 맞는 Ubuntu 24.04 AMI ID"
}

# VPN 변수 설정
variable "vpn_shared_secret" {
  description = "Pre-shared key for GCP-AWS VPN tunnel"
  type        = string
}