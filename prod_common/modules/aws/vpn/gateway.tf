# Customer Gateway (GCP쪽 external IP 필요)
resource "aws_customer_gateway" "gcp_cgw1" {
  bgp_asn    = 65001
  ip_address = var.gcp_external_ip_1 # GCP VPN Gateway의 외부 IP 주소
  type       = "ipsec.1"
  tags = {
    Name = "cgw-careerbee-prod-GCP-1"
  }
}

resource "aws_customer_gateway" "gcp_cgw2" {
  bgp_asn    = 65001
  ip_address = var.gcp_external_ip_2 # GCP VPN Gateway의 외부 IP 주소
  type       = "ipsec.1"
  tags = {
    Name = "cgw-careerbee-prod-GCP-2"
  }
}

resource "aws_vpn_gateway" "vpn_gateway" {
  vpc_id = var.vpc_id
  tags = {
    Name = "vpn-gw-careerbee-prod"
  }
}

# VPN Connection
resource "aws_vpn_connection" "gcp_vpn1" {
  vpn_gateway_id        = aws_vpn_gateway.vpn_gateway.id # or transit_gateway_id
  customer_gateway_id   = aws_customer_gateway.gcp_cgw1.id
  type                  = "ipsec.1"
  tunnel1_preshared_key = var.shared_secret_1
  static_routes_only    = true
  tags = {
    Name = "AWS-GCP_VPN-1"
  }
}

resource "aws_vpn_connection" "gcp_vpn2" {
  vpn_gateway_id        = aws_vpn_gateway.vpn_gateway.id # or transit_gateway_id
  customer_gateway_id   = aws_customer_gateway.gcp_cgw2.id
  type                  = "ipsec.1"
  tunnel1_preshared_key = var.shared_secret_2
  static_routes_only    = true
  tags = {
    Name = "AWS-GCP_VPN-2"
  }
}

# Route to GCP
resource "aws_vpn_connection_route" "to_gcp_1" {
  vpn_connection_id      = aws_vpn_connection.gcp_vpn1.id
  destination_cidr_block = var.gcp_vpc_cidr_block
}

resource "aws_vpn_connection_route" "to_gcp_2" {
  vpn_connection_id      = aws_vpn_connection.gcp_vpn2.id
  destination_cidr_block = var.gcp_vpc_cidr_block
}
