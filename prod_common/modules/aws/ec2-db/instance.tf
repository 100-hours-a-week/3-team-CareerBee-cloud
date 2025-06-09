resource "aws_instance" "ec2_db" {
  ami           = var.ami_db
  subnet_id     = var.instance_db_subnet_id
  instance_type = var.instance_type
  root_block_device {
    volume_size           = var.instance_ebs_size
    volume_type           = var.ebs_type # 예: "gp2" 또는 "gp3"
    delete_on_termination = false
  }

  vpc_security_group_ids = var.sg_ec2_ids
  key_name               = var.key_name

  tags = {
    Name = "ec2-careerbee-prod-db-azone"
  }

  user_data = templatefile("${path.module}/scripts/db_init.sh", {
    db_root_password = var.db_root_password
  })
}
