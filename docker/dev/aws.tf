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

########################################################################

resource "aws_key_pair" "key" {
  key_name   = "ssmu-key"
  public_key = base64decode(var.public_key_base64)
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

########################################################################

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
}

resource "aws_instance" "openvpn" {
  ami                         = "ami-0da165fc7156630d7" # OpenVPN Access Server (5 Connected Devices) / Self-Hosted VPN
  instance_type               = "t2.small"
  subnet_id                   = module.aws_vpc.public_subnet_ids[0]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.key.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name
  security_groups             = [aws_security_group.sg_openvpn.id]
  
  user_data = templatefile("${path.module}/scripts/ec2-openvpn-setup.tpl", {
    openvpn_pw   = var.openvpn_pw
  })
  
  tags = {
    Name = "ec2-${var.prefix}-azone-openvpn"
  }
}

resource "aws_eip_association" "eip_assoc" {
  allocation_id = data.aws_eip.existing_eip.id
  instance_id   = aws_instance.openvpn.id
}

########################################################################

# service

resource "aws_security_group" "sg_service" {
  name        = "SG-${var.prefix}-private"
  description = "Allow SSH, HTTP, HTTPS, MySQL, Scouter, FE, BE"
  vpc_id      = module.aws_vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.aws_vpc_cidr, var.gcp_vpc_cidr]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.aws_vpc_cidr]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.aws_vpc_cidr, var.gcp_vpc_cidr]
  }

  ingress {
    from_port   = 5173
    to_port     = 5173
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    from_port   = 6100
    to_port     = 6100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    from_port   = 8080
    to_port     = 8080
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
    Name = "sg-${var.prefix}"
  }
}

resource "aws_instance" "service_azone" {
  ami                         = "ami-0d5bb3742db8fc264"
  instance_type               = "t3.medium"
  subnet_id                   = module.aws_vpc.private_subnet_ids[0]
  associate_public_ip_address = false
  key_name                    = aws_key_pair.key.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name
  security_groups             = [aws_security_group.sg_service.id]

  user_data = templatefile("${path.module}/scripts/ec2-service-setup.tpl", {
    public_nopass_key_base64  = var.public_nopass_key_base64
    SSH_KEY_BASE64_NOPASS     = var.SSH_KEY_BASE64_NOPASS
    GCP_SERVER_IP             = google_compute_instance.gce.network_interface[0].network_ip
    AWS_SERVER_IP             = var.AWS_SERVER_IP
    ECR_REGISTRY              = var.ECR_REGISTRY
    AWS_DEFAULT_REGION        = var.AWS_DEFAULT_REGION
    DEV_TFVARS_ENC_PW         = var.DEV_TFVARS_ENC_PW
  })

  tags = {
    Name = "ec2-${var.prefix}-azone-service"
  }
}

# resource "aws_instance" "service_czone" {
#   ami                         = "ami-0d5bb3742db8fc264"
#   instance_type               = "t3.medium"
#   subnet_id                   = module.aws_vpc.private_subnet_ids[1]
#   associate_public_ip_address = false
#   key_name                    = aws_key_pair.key.key_name
#   iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name
#   security_groups             = [aws_security_group.sg_service.id]

#   user_data = templatefile("${path.module}/scripts/ec2-service-setup.tpl", {
#     public_nopass_key_base64  = var.public_nopass_key_base64
#     SSH_KEY_BASE64_NOPASS     = var.SSH_KEY_BASE64_NOPASS
#     gcp_server_ip             = google_compute_instance.gce.network_interface[0].network_ip
#     ECR_REGISTRY              = var.ECR_REGISTRY
#     AWS_DEFAULT_REGION        = var.AWS_DEFAULT_REGION
#   })

#   tags = {
#     Name = "ec2-${var.prefix}-czone-service"
#   }
# }

########################################################################

# DB

resource "aws_security_group" "sg_db" {
  name        = "SG-${var.prefix}-db"
  description = "Allow MySQL access from EC2 only"
  vpc_id      = module.aws_vpc.vpc_id

  ingress {
    description     = "Allow MySQL from EC2 instances"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_service.id]  # EC2가 속한 SG
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-db-${var.prefix}"
  }
}

resource "aws_instance" "db_azone" {
  ami                         = "ami-0d5bb3742db8fc264"
  instance_type               = "t3.medium"
  subnet_id                   = module.aws_vpc.private_subnet_ids[2]
  associate_public_ip_address = false
  key_name                    = aws_key_pair.key.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name
  security_groups             = [aws_security_group.sg_db.id]

  user_data = templatefile("${path.module}/scripts/ec2-db-setup.tpl", {
    public_nopass_key_base64  = var.public_nopass_key_base64
    SSH_KEY_BASE64_NOPASS     = var.SSH_KEY_BASE64_NOPASS
    DB_PASSWORD               = var.DB_PASSWORD
    DB_NAME                   = var.DB_NAME
    DB_USERNAME               = var.DB_USERNAME
    DB_PASSWORD               = var.DB_PASSWORD
    DEV_TFVARS_ENC_PW         = var.DEV_TFVARS_ENC_PW
  })    

  tags = {
    Name = "ec2-${var.prefix}-azone-db"
  }
}

# resource "aws_instance" "db_czone" {
#   ami                         = "ami-0d5bb3742db8fc264"
#   instance_type               = "t3.medium"
#   subnet_id                   = module.aws_vpc.private_subnet_ids[3]
#   associate_public_ip_address = false
#   key_name                    = aws_key_pair.key.key_name
#   iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name
#   security_groups             = [aws_security_group.sg_db.id]

#   user_data = templatefile("${path.module}/scripts/ec2-db-setup.tpl", {
#     public_nopass_key_base64  = var.public_nopass_key_base64
#     SSH_KEY_BASE64_NOPASS     = var.SSH_KEY_BASE64_NOPASS
#   })

#   tags = {
#     Name = "ec2-${var.prefix}-czone-db"
#   }
# }

########################################################################

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

########################################################################

# Target Group

resource "aws_lb_target_group" "nginx_target_group" {
  name     = "tg-nginx-${var.prefix}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.aws_vpc.vpc_id

  health_check {
    enabled             = true
    path                = "/health-check"
    protocol            = "HTTP"
    port                = "80"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

# Target 등록

resource "aws_lb_target_group_attachment" "nginx_attachment_azone" {
  target_group_arn = aws_lb_target_group.nginx_target_group.arn
  target_id        = aws_instance.service_azone.id
  port             = 80
}

# resource "aws_lb_target_group_attachment" "nginx_attachment_czone" {
#   target_group_arn = aws_lb_target_group.nginx_target_group.arn
#   target_id        = aws_instance.service_czone.id
#   port             = 80
# }

########################################################################

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

# Listener Rule

resource "aws_lb_listener_rule" "openvpn_rule" {
  listener_arn     = aws_lb_listener.https.arn
  priority         = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx_target_group.arn
  }
  condition {
    host_header {
      values = ["openvpn.dev.careerbee.co.kr"]
    }
  }
}

resource "aws_lb_listener_rule" "fe_rule" {
  listener_arn     = aws_lb_listener.https.arn
  priority         = 20
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx_target_group.arn
  }
  condition {
    host_header {
      values = ["www.dev.careerbee.co.kr"]
    }
  }
}

resource "aws_lb_listener_rule" "be_rule" {
  listener_arn     = aws_lb_listener.https.arn
  priority         = 30
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx_target_group.arn
  }
  condition {
    host_header {
      values = ["api.dev.careerbee.co.kr"]
    }
  }
}

resource "aws_lb_listener_rule" "ai_rule" {
  listener_arn     = aws_lb_listener.https.arn
  priority         = 40
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx_target_group.arn
  }
  condition {
    host_header {
      values = ["ai.dev.careerbee.co.kr"]
    }
  }
}

########################################################################

# Route53

resource "aws_route53_record" "dev_alb" {
  zone_id = data.aws_route53_zone.dev.zone_id
  name    = ""
  type    = "A"

  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www_dev_alb" {
  zone_id = data.aws_route53_zone.dev.zone_id
  name    = "www"
  type    = "A"

  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "api_dev_alb" {
  zone_id = data.aws_route53_zone.dev.zone_id
  name    = "api"
  type    = "A"

  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "ai_dev_alb" {
  zone_id = data.aws_route53_zone.dev.zone_id
  name    = "ai"
  type    = "A"

  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "openvpn_dev_alb" {
  zone_id = data.aws_route53_zone.dev.zone_id
  name    = "openvpn"
  type    = "A"

  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}