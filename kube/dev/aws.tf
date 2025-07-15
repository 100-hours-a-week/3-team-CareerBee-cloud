module "aws_vpc" {
  source              = "./modules/aws/vpc"

  prefix              = var.prefix
  vpc_cidr_block      = var.aws_vpc_cidr
  public_subnets      = [var.aws_public_subnet_azone_cidr, var.aws_public_subnet_czone_cidr]
  private_subnets     = [var.aws_private_subnet_1, var.aws_private_subnet_2, var.aws_private_subnet_3, var.aws_private_subnet_4]
  azs                 = [var.aws_azone_az, var.aws_czone_az, var.aws_azone_az, var.aws_czone_az]

  enable_nat_gateway  = true
  single_nat_gateway  = true
}

###########################################################################################################################################

resource "aws_key_pair" "key" {
  key_name   = "${var.prefix}"
  public_key = base64decode(var.public_nopass_key_base64)
}

resource "aws_iam_role" "ec2_admin_role" {
  name = "admin-role-${var.prefix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "admin_policy_attach" {
  role       = aws_iam_role.ec2_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "profile-${var.prefix}"
  role = aws_iam_role.ec2_admin_role.name
}

###########################################################################################################################################

# SG

# egress_all
resource "aws_security_group" "sg_egress_all" {
  name        = "SG-${var.prefix}-egress-all"
  description = "Allow all outbound traffic"
  vpc_id      = module.aws_vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-${var.prefix}-egress-all"
  }
}

###################################################################

# SSH
resource "aws_security_group" "sg_ssh" {
  name        = "SG-${var.prefix}-ssh"
  description = "Allow SSH Access"
  vpc_id      = module.aws_vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssmu_access_cidr_blocks
  }

  tags = {
    Name = "sg-${var.prefix}-ssh"
  }
}

###################################################################

# node_base
resource "aws_security_group" "sg_node_base" {
  name        = "SG-${var.prefix}-node_base"
  description = "Allow BGP, DNS traffic between nodes"
  vpc_id      = module.aws_vpc.vpc_id

  ingress {
    from_port   = 179
    to_port     = 179
    protocol    = "tcp"
    cidr_blocks = [var.gcp_private_subnet_cidr]
  }

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [var.gcp_private_subnet_cidr]
  }

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.gcp_private_subnet_cidr]
  }

  ingress {
    from_port   = 9443
    to_port     = 9443
    protocol    = "tcp"
    cidr_blocks = [var.gcp_private_subnet_cidr]
  }

  tags = {
    Name = "sg-${var.prefix}-node-base"
  }
}

resource "aws_security_group_rule" "bgp_self" {
  type                      = "ingress"
  from_port                 = 179
  to_port                   = 179
  protocol                  = "tcp"
  source_security_group_id  = aws_security_group.sg_node_base.id
  security_group_id         = aws_security_group.sg_node_base.id
}

resource "aws_security_group_rule" "dns_self_tcp" {
  type                      = "ingress"
  from_port                 = 53
  to_port                   = 53
  protocol                  = "tcp"
  source_security_group_id  = aws_security_group.sg_node_base.id
  security_group_id         = aws_security_group.sg_node_base.id
}

resource "aws_security_group_rule" "dns_self_udp" {
  type                      = "ingress"
  from_port                 = 53
  to_port                   = 53
  protocol                  = "udp"
  source_security_group_id  = aws_security_group.sg_node_base.id
  security_group_id         = aws_security_group.sg_node_base.id
}

resource "aws_security_group_rule" "kube_proxy_self" {
  type                      = "ingress"
  from_port                 = 9443
  to_port                   = 9443
  protocol                  = "tcp"
  source_security_group_id  = aws_security_group.sg_node_base.id
  security_group_id         = aws_security_group.sg_node_base.id
}

###################################################################

# master
resource "aws_security_group" "sg_master" {
  name = "SG-${var.prefix}-master"
  description = "Allow Master traffic"
  vpc_id = module.aws_vpc.vpc_id

  tags = {
      Name = "sg-${var.prefix}-master"
  }
}

resource "aws_security_group_rule" "worker_to_master_api" {
  type                     = "ingress"
  from_port                = 6443
  to_port                  = 6443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.sg_worker.id
  security_group_id        = aws_security_group.sg_master.id
}

resource "aws_security_group_rule" "gcp_to_master_api" {
  type                     = "ingress"
  from_port                = 6443
  to_port                  = 6443
  protocol                 = "tcp"
  cidr_blocks              = [var.gcp_private_subnet_cidr]
  security_group_id        = aws_security_group.sg_master.id
}

###################################################################

# worker
resource "aws_security_group" "sg_worker" {
  name        = "SG-${var.prefix}-worker"
  description = "Allow Worker traffic"
  vpc_id      = module.aws_vpc.vpc_id

  tags = {
    Name = "sg-${var.prefix}-worker"
  }
}

resource "aws_security_group_rule" "worker_self" {
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.sg_worker.id
  security_group_id        = aws_security_group.sg_worker.id
}

resource "aws_security_group_rule" "worker_self_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.sg_worker.id
  security_group_id        = aws_security_group.sg_worker.id
}

resource "aws_security_group_rule" "master_to_worker_kubelet" {
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.sg_master.id
  security_group_id        = aws_security_group.sg_worker.id
}

resource "aws_security_group_rule" "gcp_to_worker_kubelet" {
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  cidr_blocks              = [var.gcp_private_subnet_cidr]
  security_group_id        = aws_security_group.sg_worker.id
}

###################################################################

# DB
resource "aws_security_group" "sg_db" {
    name        = "SG-${var.prefix}-db"
    description = "Allow Kubernetes Worker db traffic"
    vpc_id      = module.aws_vpc.vpc_id

    ingress {
      from_port       = 3306
      to_port         = 3306
      protocol        = "tcp"
      security_groups = [aws_security_group.sg_worker.id]
    }

    ingress {
      from_port       = 6379
      to_port         = 6379
      protocol        = "tcp"
      security_groups = [aws_security_group.sg_worker.id]
    }

    ingress {
      from_port   = 6379
      to_port     = 6379
      protocol    = "tcp"
      cidr_blocks = [var.gcp_private_subnet_cidr]
    }

    tags = {
      Name = "sg-${var.prefix}-db"
    }
}

###########################################################################################################################################

# EC2

# master
resource "aws_instance" "k8s_master_azone" {
    ami                         = "ami-0d5bb3742db8fc264"
    instance_type               = "t3.medium"
    subnet_id                   = module.aws_vpc.private_subnet_ids[0]
    associate_public_ip_address = false
    key_name                    = aws_key_pair.key.key_name
    iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name
    security_groups             = [
      aws_security_group.sg_master.id,
      aws_security_group.sg_egress_all.id,
      aws_security_group.sg_ssh.id,
      aws_security_group.sg_node_base.id
      ]
    private_ip                  = var.aws_master_azone_private_ip
    
    root_block_device {
      volume_size = 30
      volume_type = "gp3"
      delete_on_termination = true
    }

    user_data = templatefile("${path.module}/scripts/master.sh.tpl", {
      github_org = var.github_org
      github_repo = var.github_repo
      github_token = var.github_token
      ssh_key_base64_nopass = var.ssh_key_base64_nopass
      tailscale_key = var.tailscale_key
    })

    depends_on = [module.aws_vpc]

    tags = {
        Name = "ec2-${var.prefix}-master-azone"
    }
}

###################################################################

# DB
resource "aws_instance" "k8s_worker_db_azone" {
  ami                         = "ami-0d5bb3742db8fc264"
  instance_type               = "t3.medium"
  subnet_id                   = module.aws_vpc.private_subnet_ids[2]
  associate_public_ip_address = false
  key_name                    = aws_key_pair.key.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name
  security_groups             = [
      aws_security_group.sg_worker.id,
      aws_security_group.sg_egress_all.id,
      aws_security_group.sg_ssh.id,
      aws_security_group.sg_node_base.id,
      aws_security_group.sg_db.id
      ]
  private_ip                  = var.aws_worker_db_azone_private_ip
  user_data = templatefile("${path.module}/scripts/db.sh.tpl", {
      tailscale_key = var.tailscale_key
    })

  depends_on = [module.aws_vpc]
  
  tags = {
      Name = "ec2-${var.prefix}-worker-db-azone"
  }
}

###########################################################################################################################################

# ASG

# worker
resource "aws_launch_template" "k8s_worker_azone" {
  name_prefix   = "lt-${var.prefix}-worker-"
  image_id      = "ami-0d5bb3742db8fc264"
  instance_type = "t3.medium"
  key_name = aws_key_pair.key.key_name
  network_interfaces {
    associate_public_ip_address = false
    subnet_id                   = module.aws_vpc.private_subnet_ids[0]
    security_groups             = [
      aws_security_group.sg_worker.id,
      aws_security_group.sg_egress_all.id,
      aws_security_group.sg_ssh.id,
      aws_security_group.sg_node_base.id
      ]
  }
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }
  
  user_data = base64encode(templatefile("${path.module}/scripts/worker.sh.tpl", {
    ssh_key_base64_nopass = var.ssh_key_base64_nopass
    tailscale_key = var.tailscale_key
  }))
  
  depends_on = [module.aws_vpc]

  tags = {
    Name = "ec2-${var.prefix}-worker-azone"
  }
}

resource "aws_autoscaling_group" "k8s_worker_azone" {
  name      = "asg-${var.prefix}-worker-azone"
  vpc_zone_identifier = [module.aws_vpc.private_subnet_ids[0]]
  min_size            = 2
  max_size            = 6
  desired_capacity    = 2
  health_check_type         = "EC2"
  health_check_grace_period = 300

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.k8s_worker_azone.id
        version            = "$Latest"
      }
      override {
        instance_type     = "t3.medium"
        weighted_capacity = "1"
      }
      override {
        instance_type     = "t3.large"
        weighted_capacity = "2"
      }
    }
  }

  depends_on = [module.aws_vpc]
  
  tag {
    key                 = "kubernetes.io/cluster/${var.prefix}"
    value               = "owned"
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = "true"
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.prefix}"
    value               = "true"
    propagate_at_launch = true
  }
  tag {
    key                 = "Name"
    value               = "asg-${var.prefix}-worker-azone"
    propagate_at_launch = true
  }
}

###########################################################################################################################################