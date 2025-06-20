module "vpn" {
  source              = "./modules/vpn"
  prefix              = var.prefix
  shared_secret       = var.vpn_shared_secret
  aws_router_asn      = 64512
  gcp_router_asn      = 65001
  vpn_gwy_region      = var.gcp_region
  gcp_network         = module.gcp_vpc.network_name
  gcp_vpc_cidr        = var.gcp_vpc_cidr
  aws_private_subnets = [module.aws_vpc.private_subnet_ids[0], module.aws_vpc.private_subnet_ids[1]]
  aws_vpc_id          = module.aws_vpc.vpc_id
  aws_route_table_ids  = module.aws_vpc.route_table_private_ids
}