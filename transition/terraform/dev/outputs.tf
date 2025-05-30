# GCP 인스턴스 정보 출력
output "gcp_instance_name" {
  value = google_compute_instance.gce.name
}

output "gcp_instance_public_ip" {
  value = var.gcp_static_ip
}

output "gcp_ssh_command" {
  value = "ssh -i ~/.ssh/ssmu-key ubuntu@${var.gcp_static_ip}"
}

# AWS EC2 인스턴스 정보 출력
# output "aws_instance_name" {
#   value = aws_instance.ec2.tags["Name"]
# }

# output "aws_instance_public_ip" {
#   value = data.aws_eip.existing_eip.public_ip
# }

# output "aws_ssh_command" {
#   value = "ssh -i ~/.ssh/ssmu-key ubuntu@${data.aws_eip.existing_eip.public_ip}"
# }