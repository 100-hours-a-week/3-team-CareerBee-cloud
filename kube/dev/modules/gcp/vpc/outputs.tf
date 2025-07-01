/* modules/gcp/vpc/outputs.tf */

output "network" {
  description = "생성된 VPC 네트워크"
  value       = google_compute_network.this
}

output "network_id" {
  description = "VPC 네트워크 ID"
  value       = google_compute_network.this.id
}

output "network_name" {
  description = "VPC 네트워크 이름"
  value       = google_compute_network.this.name
}

# 퍼블릭 서브넷

output "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID 목록"
  value       = [for s in google_compute_subnetwork.public : s.id]
}

output "public_subnet_cidrs" {
  description = "퍼블릭 서브넷 CIDR 블록"
  value       = [for s in google_compute_subnetwork.public : s.ip_cidr_range]
}

output "private_subnet_names" {
  description = "프라이빗 서브넷 이름 목록"
  value       = google_compute_subnetwork.private[*].name
}

# 프라이빗 서브넷

output "private_subnet_ids" {
  description = "프라이빗 서브넷 ID 목록"
  value       = [for s in google_compute_subnetwork.private : s.id]
}

output "private_subnet_cidrs" {
  description = "프라이빗 서브넷 CIDR 블록"
  value       = [for s in google_compute_subnetwork.private : s.ip_cidr_range]
}

output "public_subnet_names" {
  description = "퍼블릭 서브넷 이름 목록"
  value       = google_compute_subnetwork.public[*].name
}

# NAT

output "nat_names" {
  description = "생성된 NAT 게이트웨이 이름 목록"
  value       = [for nat in google_compute_router_nat.this : nat.name]
}

output "nat_ips" {
  description = "NAT 게이트웨이에 할당된 IP 목록"
  value       = flatten([for nat in google_compute_router_nat.this : nat.nat_ip_allocate_option == "MANUAL_ONLY" ? nat.nat_ips : []])
}

output "nat_source_subnets" {
  description = "NAT에서 소스 서브넷으로 지정된 서브넷들"
  value       = flatten([for nat in google_compute_router_nat.this : nat.source_subnetwork_ip_ranges_to_nat == "LIST_OF_SUBNETWORKS" ? nat.subnetworks[*].name : []])
}

# 방화벽

output "firewall_rule_names" {
  description = "생성된 방화벽 규칙 이름 목록"
  value       = [for fw in google_compute_firewall.custom : fw.name]
}

output "firewall_rule_ids" {
  description = "방화벽 규칙 ID 목록"
  value       = [for fw in google_compute_firewall.custom : fw.id]
}