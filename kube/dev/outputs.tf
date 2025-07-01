output "acm_arn" {
  value = data.aws_acm_certificate.careerbee_cert.arn
}

output "alb_name" {
  value = aws_lb.alb.name
}

output "argocd_admin_password_hash" {
  value = var.argocd_admin_password_hash
  sensitive = true
}