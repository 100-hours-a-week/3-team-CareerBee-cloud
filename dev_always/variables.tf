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

# AWS 관련 변수
variable "aws_region" {
  description = "The AWS region"
  type        = string
}

variable "aws_credentials_file" {
  description = "Path to AWS credentials JSON file"
  type        = string
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
