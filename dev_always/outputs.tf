output "aws_acm_certificate_arn" {
  description = "ACM 인증서 ARN"
  value       = aws_acm_certificate.careerbee_cert.arn
}

output "aws_acm_certificate_status" {
  description = "ACM 인증서 상태"
  value       = aws_acm_certificate.careerbee_cert.status
}

output "aws_ecr_repositories" {
  description = "ECR 리포지토리 이름 목록"
  value = {
    frontend  = aws_ecr_repository.frontend.repository_url
    backend   = aws_ecr_repository.backend.repository_url
    ai_server = aws_ecr_repository.ai_server.repository_url
  }
}

output "aws_s3_bucket_names" {
  description = "S3 버킷 이름 목록"
  value = {
    image = aws_s3_bucket.ssmu_bucket_image.bucket
    infra = aws_s3_bucket.ssmu_bucket_infra.bucket
  }
}

output "aws_route53_zone_dev_id" {
  description = "Route53 Zone ID for dev.careerbee.co.kr"
  value       = aws_route53_zone.dev.zone_id
}

output "google_static_ip_address" {
  description = "GCP Static IP 주소"
  value       = google_compute_address.static_ip.address
}

output "google_disk_name" {
  description = "GCP 디스크 이름"
  value       = google_compute_disk.ssmu_disk.name
}

output "aws_eip_ip" {
  description = "AWS Elastic IP"
  value       = aws_eip.static_ip.public_ip
}

output "dev_ns" {
  value = aws_route53_zone.dev.name_servers
}