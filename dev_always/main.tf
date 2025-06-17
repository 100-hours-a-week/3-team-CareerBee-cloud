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

resource "aws_s3_bucket_cors_configuration" "ssmu_bucket_image_cors" {
  bucket = aws_s3_bucket.ssmu_bucket_image.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT"]
    allowed_origins = ["https://www.dev.careerbee.co.kr", "http://localhost:5173"]
    expose_headers  = []
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_public_access_block" "ssmu_bucket_image_public_access" {
  bucket                  = aws_s3_bucket.ssmu_bucket_image.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "ssmu_bucket_image_policy" {
  bucket = aws_s3_bucket.ssmu_bucket_image.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowPublicRead",
        Effect    = "Allow",
        Principal = "*",
        Action    = [
          "s3:GetObject"
        ],
        Resource = "${aws_s3_bucket.ssmu_bucket_image.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.ssmu_bucket_image_public_access]
}

resource "aws_s3_bucket" "ssmu_bucket_infra" {
  bucket = var.s3_infra_bucket_name
  tags = var.s3_infra_bucket_tags
}

resource "aws_ecr_repository" "frontend" {
  name = "frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "ecr-careerbee-dev-frontend"
  }
}

resource "aws_ecr_repository" "backend" {
  name = "backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "ecr-careerbee-dev-backend"
  }
}

resource "aws_ecr_repository" "ai_server" {
  name = "ai-server"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "ecr-careerbee-dev-ai-server"
  }
}

resource "aws_route53_zone" "dev" {
  name = "dev.careerbee.co.kr"
}

resource "aws_acm_certificate" "careerbee_cert" {
  domain_name       = "dev.careerbee.co.kr"
  subject_alternative_names = [
    "www.dev.careerbee.co.kr",
    "api.dev.careerbee.co.kr",
    "ai.dev.careerbee.co.kr",
    "openvpn.dev.careerbee.co.kr",
    "webhook.dev.careerbee.co.kr"
  ]
  validation_method = "DNS"

  tags = {
    Name = "dev-careerbee-acm-cert"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "careerbee_cert_validation" {
  certificate_arn         = aws_acm_certificate.careerbee_cert.arn

  validation_record_fqdns = [
    for record in aws_route53_record.cert_validation_records : record.fqdn
  ]
}

resource "aws_route53_record" "cert_validation_records" {
  for_each = {
    for dvo in aws_acm_certificate.careerbee_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = aws_route53_zone.dev.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 300
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "backend"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "frontend"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "vllm" {
  name              = "vllm"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "uvicorn" {
  name              = "uvicorn"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "nginx" {
  name              = "nginx"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "fluent-bit" {
  name              = "fluent-bit"
  retention_in_days = 3
}

resource "aws_cloudwatch_log_group" "mysql" {
  name              = "mysql"
  retention_in_days = 3
}