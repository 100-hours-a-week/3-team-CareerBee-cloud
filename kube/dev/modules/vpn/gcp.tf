resource "google_compute_ha_vpn_gateway" "gwy" {
  name    = "ha-vpn-gwy-${var.prefix}"
  network = var.gcp_network
  region  = var.vpn_gwy_region
}

resource "google_compute_external_vpn_gateway" "ext_gwy" {
  for_each = aws_vpn_connection.vpn_conn

  name            = "ext-vpn-gwy-${var.prefix}-${each.key}"
  redundancy_type = "TWO_IPS_REDUNDANCY"

  interface {
    id         = 0
    ip_address = each.value.tunnel1_address
  }

  interface {
    id         = 1
    ip_address = each.value.tunnel2_address
  }
}

resource "google_compute_router" "router" {
  name    = "router-${var.prefix}"
  network = var.gcp_network
  region  = var.vpn_gwy_region

  bgp {
    asn            = var.gcp_router_asn
    advertise_mode = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]
  }
}

resource "google_compute_vpn_tunnel" "tunnel1" {
  for_each = aws_vpn_connection.vpn_conn

  name                            = "tunnel-1-${var.prefix}-${each.key}"
  shared_secret                   = var.shared_secret
  peer_external_gateway           = google_compute_external_vpn_gateway.ext_gwy[each.key].name
  peer_external_gateway_interface = 0
  region                          = var.vpn_gwy_region
  router                          = google_compute_router.router.name
  ike_version                     = "2"
  vpn_gateway                     = google_compute_ha_vpn_gateway.gwy.id
  vpn_gateway_interface           = 0
}

resource "google_compute_vpn_tunnel" "tunnel2" {
  for_each = aws_vpn_connection.vpn_conn
  
  name                            = "tunnel-2-${var.prefix}-${each.key}"
  shared_secret                   = var.shared_secret
  peer_external_gateway           = google_compute_external_vpn_gateway.ext_gwy[each.key].name
  peer_external_gateway_interface = 1
  region                          = var.vpn_gwy_region
  router                          = google_compute_router.router.name
  ike_version                     = "2"
  vpn_gateway                     = google_compute_ha_vpn_gateway.gwy.id
  vpn_gateway_interface           = 1
}

resource "google_compute_router_interface" "interface1" {
  for_each = aws_vpn_connection.vpn_conn

  name       = "interface-1-${var.prefix}-${each.key}"
  router     = google_compute_router.router.name
  region     = var.vpn_gwy_region
  ip_range   = "${each.value.tunnel1_cgw_inside_address}/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel1[each.key].name
}

resource "google_compute_router_interface" "interface2" {
  for_each = aws_vpn_connection.vpn_conn

  name       = "interface-2-${var.prefix}-${each.key}"
  router     = google_compute_router.router.name
  region     = var.vpn_gwy_region
  ip_range   = "${each.value.tunnel2_cgw_inside_address}/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel2[each.key].name
}

resource "google_compute_router_peer" "peer1" {
  for_each = aws_vpn_connection.vpn_conn

  name            = "peer-1-${var.prefix}-${each.key}"
  interface       = google_compute_router_interface.interface1[each.key].name
  peer_asn        = var.aws_router_asn
  ip_address      = each.value.tunnel1_cgw_inside_address
  peer_ip_address = each.value.tunnel1_vgw_inside_address
  router          = google_compute_router.router.name
  region          = var.vpn_gwy_region
}

resource "google_compute_router_peer" "peer2" {
  for_each = aws_vpn_connection.vpn_conn

  name            = "peer-2-${var.prefix}-${each.key}"
  interface       = google_compute_router_interface.interface2[each.key].name
  peer_asn        = var.aws_router_asn
  ip_address      = each.value.tunnel2_cgw_inside_address
  peer_ip_address = each.value.tunnel2_vgw_inside_address
  router          = google_compute_router.router.name
  region          = var.vpn_gwy_region
}