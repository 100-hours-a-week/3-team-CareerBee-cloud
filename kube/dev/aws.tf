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

# openvpn
resource "aws_security_group" "sg_openvpn" {
  name        = "SG-${var.prefix}-openvpn"
  description = "Allow OpenVPN traffic"
  vpc_id      = module.aws_vpc.vpc_id

  ingress {
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 943
    to_port     = 943
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssmu_access_cidr_blocks
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-${var.prefix}-openvpn"
  }
}

###################################################################

# master
resource "aws_security_group" "sg_master" {
  name = "SG-${var.prefix}-master"
  description = "Allow Kubernetes traffic"
  vpc_id = module.aws_vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssmu_access_cidr_blocks
  }

  ingress {
    from_port   = 179
    to_port     = 179
    protocol    = "tcp"
    cidr_blocks = [module.aws_vpc.private_subnet_cidrs[0], module.aws_vpc.private_subnet_cidrs[2]]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [module.aws_vpc.private_subnet_cidrs[0], module.aws_vpc.private_subnet_cidrs[2]]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
      Name = "sg-${var.prefix}-master"
  }
}

###################################################################

# service
resource "aws_security_group" "sg_worker" {
  name        = "SG-${var.prefix}-worker"
  description = "Allow Service traffic"
  vpc_id      = module.aws_vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssmu_access_cidr_blocks
  }

  ingress {
    from_port   = 179
    to_port     = 179
    protocol    = "tcp"
    security_groups = [aws_security_group.sg_master.id]
  }

  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    security_groups = [aws_security_group.sg_master.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-${var.prefix}-worker"
  }
}

###################################################################

# DB
resource "aws_security_group" "sg_db" {
    name        = "SG-${var.prefix}-db"
    description = "Allow Kubernetes Worker DB traffic"
    vpc_id      = module.aws_vpc.vpc_id

    ingress {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssmu_access_cidr_blocks
    }

    ingress {
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      security_groups = [aws_security_group.sg_worker.id]
    }

    ingress {
      from_port   = 179
      to_port     = 179
      protocol    = "tcp"
      security_groups = [aws_security_group.sg_master.id]
    }

    ingress {
      from_port   = 10250
      to_port     = 10250
      protocol    = "tcp"
      security_groups = [aws_security_group.sg_master.id]
    }

    egress {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
      Name = "sg-${var.prefix}-db"
    }
}

###########################################################################################################################################

# EC2

# openvpn
resource "aws_instance" "openvpn" {
  ami                         = "ami-0da165fc7156630d7" # OpenVPN Access Server (5 Connected Devices) / Self-Hosted VPN
  instance_type               = "t2.medium"
  subnet_id                   = module.aws_vpc.public_subnet_ids[0]
  associate_public_ip_address = false
  key_name                    = aws_key_pair.key.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name
  security_groups             = [aws_security_group.sg_openvpn.id]
  
  user_data = templatefile("${path.module}/scripts/openvpn.sh.tpl", {
    openvpn_pw = var.openvpn_pw
  })
  
  depends_on = [module.aws_vpc]

  tags = {
    Name = "ec2-${var.prefix}-openvpn-azone"
  }
}

resource "aws_eip_association" "eip_assoc" {
  allocation_id = data.aws_eip.existing_eip.id
  instance_id   = aws_instance.openvpn.id
}

###################################################################

# master
resource "aws_instance" "k8s_master_azone" {
    ami                         = "ami-0d5bb3742db8fc264"
    instance_type               = "t3.medium"
    subnet_id                   = module.aws_vpc.private_subnet_ids[0]
    associate_public_ip_address = false
    key_name                    = aws_key_pair.key.key_name
    iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name
    security_groups             = [aws_security_group.sg_master.id]
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
  security_groups             = [aws_security_group.sg_db.id]
  private_ip                  = var.aws_worker_db_azone_private_ip
  user_data = <<-EOF
  #!/bin/bash
  hostnamectl set-hostname db
  echo "127.0.1.1 db" >> /etc/hosts
  echo "preserve_hostname: true" >> /etc/cloud/cloud.cfg
  EOF

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
    security_groups             = [aws_security_group.sg_worker.id]
  }
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }
  
  user_data = base64encode(templatefile("${path.module}/scripts/worker.sh.tpl", {
    ssh_key_base64_nopass = var.ssh_key_base64_nopass
  }))
  
  depends_on = [module.aws_vpc]

  tags = {
    Name = "ec2-${var.prefix}-worker-azone"
  }
}

resource "aws_autoscaling_group" "k8s_worker_azone" {
  name      = "asg-${var.prefix}-worker-azone"
  launch_template {
    id      = aws_launch_template.k8s_worker_azone.id
    version = "$Latest"
  }
  vpc_zone_identifier = [module.aws_vpc.private_subnet_ids[0]]
  min_size            = 1
  max_size            = 5
  desired_capacity    = 1

  depends_on = [module.aws_vpc]
  
  tag {
    key                 = "kubernetes.io/cluster/${var.prefix}"
    value               = "owned"
    propagate_at_launch = true
  }
}

###########################################################################################################################################

# ALB

resource "aws_security_group" "sg_alb" {
  name        = "SG-${var.prefix}-alb"
  description = "Allow HTTP and HTTPS access to ALB"
  vpc_id      = module.aws_vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-${var.prefix}-alb"
  }
}

resource "aws_lb" "alb" {
  name               = "alb-${var.prefix}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_alb.id]
  subnets            = module.aws_vpc.public_subnet_ids

  tags = {
    Name = "alb-${var.prefix}"
  }
}

###################################################################

# ALB Listener

resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.careerbee_cert.arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404 Not Found"
      status_code  = "404"
    }
  }
}

###################################################################

# ALB Target Group
resource "aws_lb_target_group" "openvpn_tg" {
  name        = "tg-${var.prefix}-openvpn"
  port        = 943
  protocol    = "HTTPS"
  target_type = "instance"
  vpc_id      = module.aws_vpc.vpc_id

  health_check {
    protocol            = "HTTPS"
    port                = "traffic-port"
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name = "tg-${var.prefix}-openvpn"
  }
}

resource "aws_lb_target_group_attachment" "openvpn_attach" {
  target_group_arn = aws_lb_target_group.openvpn_tg.arn
  target_id        = aws_instance.openvpn.id
  port             = 943
}

###################################################################

#  Listener Rule
resource "aws_lb_listener_rule" "openvpn_https_rule" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.openvpn_tg.arn
  }

  condition {
    host_header {
      values = ["openvpn.${data.aws_route53_zone.dev.name}"]
    }
  }
}

###########################################################################################################################################

# Route53

resource "aws_route53_record" "alb_record" {
  zone_id = data.aws_route53_zone.dev.zone_id
  name    = "${data.aws_route53_zone.dev.name}"
  type    = "A"
  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "openvpn_record" {
  zone_id = data.aws_route53_zone.dev.zone_id
  name    = "openvpn.${data.aws_route53_zone.dev.name}"
  type    = "A"
  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "argocd_record" {
  zone_id = data.aws_route53_zone.dev.zone_id
  name    = "argocd.${data.aws_route53_zone.dev.name}"
  type    = "A"
  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "fe_record" {
  zone_id = data.aws_route53_zone.dev.zone_id
  name    = "www.${data.aws_route53_zone.dev.name}"
  type    = "A"
  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "be_record" {
  zone_id = data.aws_route53_zone.dev.zone_id
  name    = "api.${data.aws_route53_zone.dev.name}"
  type    = "A"
  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "ai_record" {
  zone_id = data.aws_route53_zone.dev.zone_id
  name    = "ai.${data.aws_route53_zone.dev.name}"
  type    = "A"
  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "prometheus_record" {
  zone_id = data.aws_route53_zone.dev.zone_id
  name    = "prometheus.${data.aws_route53_zone.dev.name}"
  type    = "A"
  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "grafana_record" {
  zone_id = data.aws_route53_zone.dev.zone_id
  name    = "grafana.${data.aws_route53_zone.dev.name}"
  type    = "A"
  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

###########################################################################################################################################

# WAF

resource "aws_wafv2_web_acl" "web_acl" {
  name        = "waf-${var.prefix}-acl"
  description = "WafACL for CareerBee"
  scope       = "REGIONAL"
  default_action {
    allow {}
  }
  
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "careerbeeWebACL"
    sampled_requests_enabled   = true
  }

  # AWS에서 제공하는 보안 규칙 모음
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSCommon"
      sampled_requests_enabled   = true
    }
  }

  tags = {
    Name = "waf-${var.prefix}-acl"
  }
}

resource "aws_wafv2_web_acl_association" "alb_association" {
  resource_arn = aws_lb.alb.arn
  web_acl_arn  = aws_wafv2_web_acl.web_acl.arn
}

###########################################################################################################################################