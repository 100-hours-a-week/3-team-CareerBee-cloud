resource "aws_customer_gateway" "gcp_gateway" {
  bgp_asn    = 65001
  ip_address = var.gcp_static_ip
  type       = "ipsec.1"
}

resource "aws_vpn_gateway" "vpn_gw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "aws-vpn-gateway"
  }
}

resource "aws_vpn_connection" "vpn_connection" {
  vpn_gateway_id      = aws_vpn_gateway.vpn_gw.id
  customer_gateway_id = aws_customer_gateway.gcp_gateway.id
  type                = "ipsec.1"
  static_routes_only  = true
}

resource "aws_vpn_connection_route" "to_gcp" {
  vpn_connection_id      = aws_vpn_connection.vpn_connection.id
  destination_cidr_block = var.gcp_subnet_cidr
}

resource "google_compute_vpn_gateway" "gcp_vpn_gateway" {
  name    = "gcp-vpn-gateway"
  network = google_compute_network.vpc.id
  region  = var.gcp_region
}

resource "google_compute_forwarding_rule" "gcp_esp" {
  name        = "gcp-vpn-esp"
  region      = var.gcp_region
  ip_protocol = "ESP"
  ip_address  = var.gcp_static_ip
  target      = google_compute_vpn_gateway.gcp_vpn_gateway.id
}

resource "google_compute_forwarding_rule" "gcp_udp500" {
  name        = "gcp-vpn-udp500"
  region      = var.gcp_region
  ip_protocol = "UDP"
  port_range  = "500"
  ip_address  = var.gcp_static_ip
  target      = google_compute_vpn_gateway.gcp_vpn_gateway.id
}

resource "google_compute_forwarding_rule" "gcp_udp4500" {
  name        = "gcp-vpn-udp4500"
  region      = var.gcp_region
  ip_protocol = "UDP"
  port_range  = "4500"
  ip_address  = var.gcp_static_ip
  target      = google_compute_vpn_gateway.gcp_vpn_gateway.id
}

resource "google_compute_vpn_tunnel" "vpn_tunnel" {
  name               = "gcp-to-aws-tunnel"
  region             = var.gcp_region
  target_vpn_gateway = google_compute_vpn_gateway.gcp_vpn_gateway.id
  peer_ip            = var.aws_static_ip
  shared_secret      = var.vpn_shared_secret
  ike_version        = 2

  local_traffic_selector  = [var.gcp_subnet_cidr]
  remote_traffic_selector = [var.aws_subnet_cidr]
}

resource "google_compute_route" "to_aws_vpn" {
  name                   = "route-to-aws-vpn"
  network                = google_compute_network.vpc.name
  dest_range             = var.aws_subnet_cidr
  priority               = 1000
  next_hop_vpn_tunnel    = google_compute_vpn_tunnel.vpn_tunnel.id
}

resource "aws_route" "to_gcp_vpn" {
  route_table_id         = aws_route_table.rt.id
  destination_cidr_block = var.gcp_subnet_cidr
  gateway_id             = aws_vpn_gateway.vpn_gw.id
}