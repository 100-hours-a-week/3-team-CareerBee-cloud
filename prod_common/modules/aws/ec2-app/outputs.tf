output "instance_ids" {
  value = try([
    for instance in aws_instance.ec2_app : try(instance.id, null)
  ], [])
}

output "instance_names" {
  value = [
    for instance in aws_instance.ec2_app :
    try(instance.tags["Name"], null)
  ]
}
