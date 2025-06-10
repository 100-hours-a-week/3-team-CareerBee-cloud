locals {
  customer_gateways = {
    "0" = google_compute_ha_vpn_gateway.gwy.vpn_interfaces[0].ip_address
    "1" = google_compute_ha_vpn_gateway.gwy.vpn_interfaces[1].ip_address
  }
}

resource "aws_customer_gateway" "gwy" {
  for_each = local.customer_gateways

  device_name = "cgwy-${var.prefix}-${each.key}"
  bgp_asn     = var.gcp_router_asn
  type        = "ipsec.1"
  ip_address  = each.value
}

resource "aws_ec2_transit_gateway" "tgw" {
  amazon_side_asn                 = var.aws_router_asn
  description                     = "Transit Gateway"
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  vpn_ecmp_support                = "enable"
  dns_support                     = "enable"

  tags = {
    Name = "tgw-${var.prefix}"
  }
}

resource "awscc_ec2_transit_gateway_attachment" "tgw_attachment" {
  subnet_ids         = var.aws_private_subnets
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = var.aws_vpc_id

  tags = [
    {
      key   = "Name"
      value = "tgw-attachment-${var.prefix}"
    }
  ]
}

resource "aws_vpn_connection" "vpn_conn" {
  for_each = aws_customer_gateway.gwy

  customer_gateway_id   = each.value.id
  type                  = "ipsec.1"
  transit_gateway_id    = aws_ec2_transit_gateway.tgw.id
  tunnel1_preshared_key = var.shared_secret
  tunnel2_preshared_key = var.shared_secret

  tags = {
    Name = "vpn-conn-${var.prefix}-${each.key}"
  }
}