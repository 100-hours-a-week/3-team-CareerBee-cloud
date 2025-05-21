# Google
provider "google" {
  project     = var.gcp_project_id
  region      = var.gcp_region
  credentials = file(var.gcp_credentials_file)
}

resource "google_compute_address" "static_ip" {
  name   = var.gcp_static_ip_name
  region = var.gcp_region
}

output "gcp_static_ip_address" {
  value = google_compute_address.static_ip.address
}

resource "google_compute_disk" "ssmu_disk" {
  name  = var.gcp_disk_name
  type  = var.gcp_disk_type
  zone  = var.gcp_zone
  size  = var.gcp_disk_size
}

# AWS
locals {
  aws_creds = jsondecode(file(var.aws_credentials_file))
}

provider "aws" {
  region     = var.aws_region
  access_key = local.aws_creds.aws_access_key_id
  secret_key = local.aws_creds.aws_secret_access_key
}

resource "aws_eip" "static_ip" {
}

output "aws_static_ip_address" {
  value = aws_eip.static_ip.public_ip
}

resource "aws_s3_bucket" "ssmu_bucket_tfstate" {
  bucket = var.s3_tfstate_bucket_name
  tags = var.s3_tfstate_bucket_tags
}

resource "aws_s3_bucket" "ssmu_bucket_image" {
  bucket = var.s3_image_bucket_name
  tags = var.s3_image_bucket_tags
}

resource "aws_s3_bucket" "ssmu_bucket_infra" {
  bucket = var.s3_infra_bucket_name
  tags = var.s3_infra_bucket_tags
}