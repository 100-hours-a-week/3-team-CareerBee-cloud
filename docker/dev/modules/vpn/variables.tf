variable "vpn_gwy_region" {
  type = string
}

variable "gcp_router_asn" {
  type = string
}

variable "aws_router_asn" {
  type = string
}

variable "aws_vpc_id" {
  type = string
}

variable "gcp_network" {
  type        = string
  description = "Name of the GCP network."
}

variable "gcp_vpc_cidr" {
  description = "GCP VPC CIDR block"
  type        = string
}

variable "aws_private_subnets" {
  type = list(string)
}

variable "aws_route_table_ids" {
  type = list(string)
}

variable "shared_secret" {
  type = string
}

variable "prefix" {
  type        = string
  description = "Prefix used for all the resources."
}