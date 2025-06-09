output "instance_id" {
  value = aws_instance.ec2_app.id
}

output "instance_name" {
  value = aws_instance.ec2_app.tags["Name"]
}
