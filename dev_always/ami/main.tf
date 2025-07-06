provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
}

data "aws_instance" "openvpn" {
  filter {
    name   = "tag:Name"
    values = ["ec2-careerbee-dev-openvpn-azone"]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}
data "aws_instance" "openvpn_test" {
  filter {
    name   = "tag:Name"
    values = ["ec2-careerbee-test-openvpn-azone"]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

resource "aws_ami_from_instance" "openvpn_backup" {
  name = "openvpn-ami"
  source_instance_id = data.aws_instance.openvpn.id
  snapshot_without_reboot = true
}
resource "aws_ami_from_instance" "openvpn_test_backup" {
  name = "openvpn-ami-test"
  source_instance_id = data.aws_instance.openvpn_test.id
  snapshot_without_reboot = true
}

output "openvpn_ami_id" {
  value = aws_ami_from_instance.openvpn_backup.id
}
output "openvpn_test_ami_id" {
  value = aws_ami_from_instance.openvpn_test_backup.id
}