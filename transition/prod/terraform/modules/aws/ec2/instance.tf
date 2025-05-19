resource "aws_instance" "ec2" {
  associate_public_ip_address = var.associate_public_ip_address
  ami                         = var.ami
  subnet_id                   = var.instance_subnet_id
  instance_type               = var.instance_type
  root_block_device {
    volume_size           = var.instance_ebs_size
    volume_type           = var.ebs_type # 예: "gp2" 또는 "gp3"
    delete_on_termination = false
  }

  vpc_security_group_ids = var.sg_ec2_ids
  key_name               = var.key_name

  tags = {
    Name = "EC2-CAREERBEE-PROD-Azone"
  }

  user_data = templatefile("${path.module}/scripts/init.sh", {
    db_root_password = var.db_root_password
  })
}

# EIP 생성
resource "aws_eip" "eip_azone" {
  domain = "vpc"
  tags = {
    Name = "EIP-CAREERBEE-PROD"
  }

}

# EIP와 인스턴스 연결
resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.ec2.id
  allocation_id = aws_eip.eip_azone.id

  depends_on = [aws_eip.eip_azone]
}
