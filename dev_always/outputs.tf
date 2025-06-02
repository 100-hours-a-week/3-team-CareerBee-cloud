output "gcp_static_ip_address" {
  value = google_compute_address.static_ip.address
}

output "aws_static_ip_address" {
  value = aws_eip.static_ip.public_ip
}

output "careerbee_ns" {
  value = aws_route53_zone.careerbee.name_servers
}