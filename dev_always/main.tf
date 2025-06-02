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

resource "google_compute_disk" "ssmu_disk" {
  name  = var.gcp_disk_name
  type  = var.gcp_disk_type
  zone  = var.gcp_zone
  size  = var.gcp_disk_size
}

# AWS
provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
}

resource "aws_eip" "static_ip" {
}

resource "aws_s3_bucket" "ssmu_bucket_image" {
  bucket = var.s3_image_bucket_name
  tags = var.s3_image_bucket_tags
}

resource "aws_s3_bucket" "ssmu_bucket_infra" {
  bucket = var.s3_infra_bucket_name
  tags = var.s3_infra_bucket_tags
}

resource "aws_route53_zone" "careerbee" {
  name = "careerbee.co.kr"
}

resource "aws_route53_record" "frontend" {
  zone_id = aws_route53_zone.careerbee.zone_id
  name    = "dev.careerbee.co.kr"
  type    = "A"
  ttl     = 300
  records = [aws_eip.static_ip.public_ip]
}

resource "aws_route53_record" "backend" {
  zone_id = aws_route53_zone.careerbee.zone_id
  name    = "dev-api.careerbee.co.kr"
  type    = "A"
  ttl     = 300
  records = [aws_eip.static_ip.public_ip]
}

resource "aws_route53_record" "ai" {
  zone_id = aws_route53_zone.careerbee.zone_id
  name    = "dev-ai.careerbee.co.kr"
  type    = "A"
  ttl     = 300
  records = [google_compute_address.static_ip.address]
}
