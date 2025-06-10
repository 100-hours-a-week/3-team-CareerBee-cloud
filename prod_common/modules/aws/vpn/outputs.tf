output "aws_external_ip_1" {
  value = aws_vpn_connection.gcp_vpn1.tunnel1_address
}

output "aws_external_ip_2" {
  value = aws_vpn_connection.gcp_vpn2.tunnel2_address
}
