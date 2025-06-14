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

resource "aws_ec2_transit_gateway_route" "to_gcp" {
  destination_cidr_block         = var.gcp_vpc_cidr
  transit_gateway_attachment_id  = awscc_ec2_transit_gateway_attachment.tgw_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.tgw.association_default_route_table_id

  depends_on = [
    aws_vpn_connection.vpn_conn,
    awscc_ec2_transit_gateway_attachment.tgw_attachment
  ]
}

resource "aws_route" "to_gcp" {
  count = length(var.aws_route_table_ids)

  route_table_id         = var.aws_route_table_ids[count.index]
  destination_cidr_block = var.gcp_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
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