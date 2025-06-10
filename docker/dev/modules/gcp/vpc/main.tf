/* modules/gcp_vpc/main.tf */

resource "google_compute_network" "this" {
  name                    = "vpc-${var.prefix}"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "public" {
  count = length(var.public_subnets)

  name                      = "subnet-public-${var.prefix}-${count.index + 1}"
  ip_cidr_range             = var.public_subnets[count.index]
  region                    = var.regions[count.index]
  network                   = google_compute_network.this.id
  private_ip_google_access  = false
}

resource "google_compute_subnetwork" "private" {
  count = length(var.private_subnets)

  name                      = "subnet-private-${var.prefix}-${count.index + 1}"
  ip_cidr_range             = var.private_subnets[count.index]
  region                    = var.regions[count.index]
  network                   = google_compute_network.this.id
  private_ip_google_access  = true
}

resource "google_compute_router" "this" {
  for_each = { for nat in var.nat_configs : nat.name => nat }

  name    = "router-${each.value.name}-${var.prefix}"
  region  = each.value.region
  network = google_compute_network.this.name
}

resource "google_compute_router_nat" "this" {
  for_each = { for nat in var.nat_configs : nat.name => nat }

  name                               = "nat-${each.value.name}-${var.prefix}"
  router                             = google_compute_router.this[each.key].name
  region                             = each.value.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_firewall" "custom" {
  for_each = { for rule in var.firewall_rules : rule.name => rule }

  name    = "fw-${each.value.name}-${var.prefix}"
  network = google_compute_network.this.name

  allow {
    protocol = each.value.protocol
    ports    = each.value.ports
  }

  source_ranges = each.value.source_ranges
  direction     = each.value.direction
  priority      = each.value.priority
  disabled      = false
}