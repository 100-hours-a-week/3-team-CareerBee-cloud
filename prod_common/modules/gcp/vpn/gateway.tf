# Cloud VPN Gateway (GCP 고정)
resource "google_compute_ha_vpn_gateway" "aws_vpn_gateway" {
  name    = "aws-vpn-gateway"
  network = var.gcp_vpc_self_link
  region  = "asia-northeast3"

}

# 첫 번째 터널 (AWS VPN Connection 1에 대응)
resource "google_compute_vpn_tunnel" "aws_vpn_tunnel_1" {
  name                    = "aws-vpn-tunnel-1"
  region                  = "asia-northeast3"
  target_vpn_gateway      = google_compute_ha_vpn_gateway.aws_vpn_gateway.id
  peer_ip                 = var.aws_external_ip_1 # AWS의 VPN 터널 1 외부 IP
  shared_secret           = var.shared_secret_1
  vpn_gateway_interface   = 0
  local_traffic_selector  = [var.gcp_vpc_cidr_block]
  remote_traffic_selector = [var.aws_vpc_cidr_block]

  ike_version = 2

}

# 두 번째 터널 (AWS VPN Connection 2에 대응)
resource "google_compute_vpn_tunnel" "aws_vpn_tunnel_2" {
  name                    = "aws-vpn-tunnel-2"
  region                  = "asia-northeast3"
  target_vpn_gateway      = google_compute_ha_vpn_gateway.aws_vpn_gateway.id
  peer_ip                 = var.aws_external_ip_2 # AWS의 VPN 터널 2 외부 IP
  shared_secret           = var.shared_secret_2
  vpn_gateway_interface   = 1
  local_traffic_selector  = [var.gcp_vpc_cidr_block]
  remote_traffic_selector = [var.aws_vpc_cidr_block]

  ike_version = 2
}

# 두 개의 라우트 (둘 다 동일 CIDR로 가능, priority 다르게 설정 가능)
resource "google_compute_route" "aws_vpn_route_1" {
  name                = "route-to-aws-1"
  network             = var.gcp_vpc_self_link
  dest_range          = var.aws_vpc_cidr_block
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.aws_vpn_tunnel_1.id
  priority            = 1000
}

resource "google_compute_route" "aws_vpn_route_2" {
  name                = "route-to-aws-2"
  network             = var.gcp_vpc_self_link
  dest_range          = var.aws_vpc_cidr_block
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.aws_vpn_tunnel_2.id
  priority            = 1001
}
