resource "aws_instance" "ec2_openvpn" {
  ami           = var.ami_openvpn
  subnet_id     = var.instance_public_subnet_id
  instance_type = var.instance_type
  root_block_device {
    volume_size           = var.instance_ebs_size
    volume_type           = var.ebs_type # 예: "gp2" 또는 "gp3"
    delete_on_termination = false
  }

  vpc_security_group_ids = var.sg_ec2_ids
  key_name               = var.key_name

  tags = {
    Name = "ec2-careerbee-prod-openvpn"
  }
}

# EIP 할당된 ID로 EC2 인스턴스에 연결
resource "aws_eip_association" "openvpn_eip_assoc" {
  instance_id   = aws_instance.ec2_openvpn.id
  allocation_id = "eipalloc-035180087bbdc6345"
}
