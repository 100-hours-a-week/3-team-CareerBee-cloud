resource "google_compute_network" "vpc_network" {
  name                    = var.name
  auto_create_subnetworks = false
  routing_mode           = var.routing_mode
}

resource "google_compute_subnetwork" "subnetworks" {
  for_each               = { for subnet in var.subnetworks : subnet.name => subnet }

  name                  = each.value.name
  ip_cidr_range         = each.value.ip_cidr_range
  region                = each.value.region
  network               = google_compute_network.vpc_network.id
  private_ip_google_access = each.value.private_ip_google_access
}

resource "google_compute_firewall" "rules" {
  for_each = { for rule in var.firewall_rules : rule.name => rule }

  name    = each.value.name
  network = google_compute_network.vpc_network.name
  direction = lookup(each.value, "direction", "INGRESS")
  priority  = lookup(each.value, "priority", 1000)

  allow {
    protocol = each.value.protocol
    ports    = each.value.ports
  }

  source_ranges      = lookup(each.value, "source_ranges", [])
  destination_ranges = lookup(each.value, "destination_ranges", [])
  target_tags        = lookup(each.value, "target_tags", [])
}