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

output "mysql_username" {
  value = var.mysql_username
}

output "mysql_password" {
  value = var.mysql_password
  sensitive = true
}

output "mysql_database" {
  value = var.mysql_database
}

output "prefix" {
  value = var.prefix
}
output "aws_region" {
  value = var.aws_region
}
output "aws_vpc_id" {
  value = module.aws_vpc.vpc_id
}