output "instance_id" {
  value = aws_instance.ec2.id
}

output "instance_name" {
  value = aws_instance.ec2.tags["Name"]
}