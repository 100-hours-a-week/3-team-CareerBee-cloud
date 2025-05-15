output "managed_zone_names" {
  value = [for z in google_dns_managed_zone.zones : z.name]
}

output "record_set_names" {
  value = [for r in google_dns_record_set.records : r.name]
}