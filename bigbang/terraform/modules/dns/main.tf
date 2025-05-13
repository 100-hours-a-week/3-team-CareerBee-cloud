resource "google_dns_managed_zone" "zones" {
  for_each = { for zone in var.managed_zones : zone.name => zone }

  name        = each.value.name
  dns_name    = each.value.dns_name
  description = each.value.description
  labels      = each.value.labels
  visibility  = each.value.visibility

  # dynamic "private_visibility_config" {
  #   for_each = each.value.visibility == "private" ? [1] : []
  #   content {
  #     dynamic "network" {
  #       for_each = each.value.private_visibility_networks
  #       content {
  #         network_url = network.value
  #       }
  #     }
  #   }
  # }
}

resource "google_dns_record_set" "records" {
  for_each = { for record in var.record_sets : "${record.zone}:${record.name}:${record.type}" => record }

  name         = each.value.name
  type         = each.value.type
  ttl          = each.value.ttl
  managed_zone = each.value.zone
  rrdatas      = each.value.rrdatas
}