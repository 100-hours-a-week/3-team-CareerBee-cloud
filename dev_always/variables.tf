# GCP 관련 변수
variable "gcp_project_id" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_credentials_file" {
  description = "Path to GCP credentials JSON file"
  type        = string
}

variable "gcp_region" {
  description = "GCP region"
  type        = string
}

variable "gcp_zone" {
  description = "GCP zone"
  type        = string
}

variable "gcp_static_ip_name" {
  description = "Name of the static IP address"
  type        = string
}

variable "gcp_disk_name" {
  description = "Name of the compute disk"
  type        = string
}

variable "gcp_disk_type" {
  description = "Type of compute disk"
  type        = string
}

variable "gcp_disk_size" {
  description = "Size of the compute disk in GB"
  type        = number
}

# AWS 관련 변수
variable "aws_region" {
  description = "The AWS region"
  type        = string
}

variable "aws_access_key_id" {
  type        = string
  sensitive = true
}

variable "aws_secret_access_key" {
  type        = string
  sensitive   = true
}

variable "s3_image_bucket_name" {
  description = "Name of the S3 bucket for storing images"
  type        = string
}

variable "s3_image_bucket_tags" {
  description = "Tags for the image S3 bucket"
  type        = map(string)
}

variable "s3_infra_bucket_name" {
  description = "Name of the S3 bucket for infrastructure-related files"
  type        = string
}

variable "s3_infra_bucket_tags" {
  description = "Tags for the infrastructure S3 bucket"
  type        = map(string)
}


variable "github_token" {
  description = "GitHub Personal Access Token"
  type        = string
  sensitive   = true
}

variable "github_repo" {
  description = "GitHub repo in the form owner/repo"
  type        = string
}

variable "workflow_1" {
  type = string
  description = "첫 번째 워크플로 파일 이름"
}

variable "workflow_2" {
  type = string
  description = "두 번째 워크플로 파일 이름"
}