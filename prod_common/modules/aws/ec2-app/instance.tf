resource "aws_instance" "ec2_app" {
  ami           = var.ami
  subnet_id     = var.instance_app_subnet_id
  instance_type = var.instance_type
  root_block_device {
    volume_size           = var.instance_ebs_size
    volume_type           = var.ebs_type # 예: "gp2" 또는 "gp3"
    delete_on_termination = false
  }

  vpc_security_group_ids = var.sg_ec2_ids
  key_name               = var.key_name

  tags = {
    Name = "ec2-careerbee-prod-app-azone"
  }

  user_data = templatefile("${path.module}/scripts/init.sh", {})
}

# Name 태그 기준으로 EIP 리스트 조회
# data "aws_eips" "tagged_eip" {
#   filter {
#     name   = "tag:Name"
#     values = ["eip-careerbee-prod"]
#   }
# }


# # EIP와 인스턴스 연결
# resource "aws_eip_association" "eip_assoc" {
#   instance_id   = aws_instance.ec2.id
#   allocation_id = var.eip_allocation_id
# }
