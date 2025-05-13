output "instance_names" {
  value = [for vm in google_compute_instance.vm_instance : vm.name]
}

output "internal_ips" {
  value = { for name, vm in google_compute_instance.vm_instance : name => vm.network_interface[0].network_ip }
}

output "external_ips" {
  value = { for name, vm in google_compute_instance.vm_instance : name => vm.network_interface[0].access_config[0].nat_ip }
}

output "public_ips" {
  value = { for name, inst in google_compute_instance.vm_instance : name => inst.network_interface[0].access_config[0].nat_ip }
}