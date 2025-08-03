output "aws_acm_certificate_arn" {
  description = "ACM 인증서 ARN"
  value       = aws_acm_certificate.careerbee_cert.arn
}
# output "aws_acm_certificate_test_arn" {
#   description = "ACM 인증서 TEST ARN"
#   value       = aws_acm_certificate.careerbee_cert_test.arn
# }

output "aws_ecr_repositories" {
  description = "ECR 리포지토리 이름 목록"
  value = {
    frontend  = aws_ecr_repository.frontend.repository_url
    backend   = aws_ecr_repository.backend.repository_url
    ai_server = aws_ecr_repository.ai_server.repository_url
  }
}

# output "aws_eip_ip" {
#   description = "AWS Elastic IP"
#   value       = aws_eip.static_ip.public_ip
# }