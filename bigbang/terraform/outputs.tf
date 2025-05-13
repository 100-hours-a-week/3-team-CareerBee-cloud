output "instance_public_ip" {
  value = module.gce.public_ips["ssmu-dev-instance"]
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/ssmu-key ubuntu@${module.gce.public_ips["ssmu-dev-instance"]}"
}