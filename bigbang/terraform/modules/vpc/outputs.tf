output "vpc_name" {
  value = google_compute_network.vpc_network.name
}

output "subnetwork_names" {
  value = [for s in google_compute_subnetwork.subnetworks : s.name]
}