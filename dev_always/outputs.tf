output "gcp_static_ip_address" {
  value = google_compute_address.static_ip.address
}

output "aws_static_ip_address" {
  value = aws_eip.static_ip.public_ip
}

output "acm_validation_records" {
  value = [
    for dvo in aws_acm_certificate.careerbee_cert.domain_validation_options : {
      domain_name = dvo.domain_name
      resource_record_name = dvo.resource_record_name
      resource_record_type = dvo.resource_record_type
      resource_record_value = dvo.resource_record_value
    }
  ]
}