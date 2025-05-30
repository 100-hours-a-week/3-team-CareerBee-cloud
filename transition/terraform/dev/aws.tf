# provider "aws" {
#   region     = var.aws_region
#   access_key = var.aws_access_key_id
#   secret_key = var.aws_secret_access_key
# }

# resource "aws_vpc" "vpc" {
#   cidr_block           = var.aws_vpc_cidr
#   enable_dns_hostnames = true

#   tags = {
#     Name = "vpc-careerbee-dev"
#   }
# }

# resource "aws_subnet" "subnet" {
#   vpc_id                  = aws_vpc.vpc.id
#   cidr_block              = var.aws_subnet_cidr
#   map_public_ip_on_launch = true
#   availability_zone       = var.aws_az

#   tags = {
#     Name = "subnet-careerbee-dev-public-azone"
#   }
# }

# resource "aws_internet_gateway" "igw" {
#   vpc_id = aws_vpc.vpc.id

#   tags = {
#     Name = "igw-careerbee-dev"
#   }
# }

# resource "aws_route_table" "rt" {
#   vpc_id = aws_vpc.vpc.id

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.igw.id
#   }
# }

# resource "aws_route_table_association" "rta" {
#   subnet_id      = aws_subnet.subnet.id
#   route_table_id = aws_route_table.rt.id
# }

# resource "aws_security_group" "sg" {
#   name        = "SG-careerbee-dev"
#   description = "Allow SSH, HTTP, HTTPS"
#   vpc_id      = aws_vpc.vpc.id

#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = var.aws_ssh_access_cidr_blocks
#   }

#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     from_port   = 3306
#     to_port     = 3306
#     protocol    = "tcp"
#     cidr_blocks = var.aws_db_access_cidr_blocks
#   }

#   ingress {
#     from_port   = 5173
#     to_port     = 5173
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#     ingress {
#     from_port   = 6100
#     to_port     = 6100
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#     ingress {
#     from_port   = 8080
#     to_port     = 8080
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "sg-careerbee-dev"
#   }
# }

# resource "aws_key_pair" "key" {
#   key_name   = "ssmu-key"
#   public_key = base64decode(var.public_key_base64)
# }

# data "aws_eip" "existing_eip" {
#   public_ip = var.aws_static_ip
# }

# resource "aws_iam_role" "ec2_admin_role" {
#   name = "careerbee-dev-admin-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect = "Allow",
#       Principal = {
#         Service = "ec2.amazonaws.com"
#       },
#       Action = "sts:AssumeRole"
#     }]
#   })
# }

# # 관리형 정책 연결
# resource "aws_iam_role_policy_attachment" "admin_policy_attach" {
#   role       = aws_iam_role.ec2_admin_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
# }

# resource "aws_iam_instance_profile" "ec2_instance_profile" {
#   name = "careerbee-dev-profile"
#   role = aws_iam_role.ec2_admin_role.name
# }

# resource "aws_instance" "ec2" {
#   ami                    = var.aws_ubuntu_ami_id
#   instance_type          = "t3.large"
#   subnet_id              = aws_subnet.subnet.id
#   vpc_security_group_ids = [aws_security_group.sg.id]
#   key_name               = aws_key_pair.key.key_name
#   associate_public_ip_address = false
#   iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

#   user_data = templatefile("${path.module}/scripts/ec2-startup.tpl", {
#     DOMAIN                    = var.domain
#     EMAIL                     = var.email
#     BUCKET_BACKUP             = var.bucket_backup
    
#     AWS_STATIC_IP             = var.aws_static_ip
#     DB_PASSWORD               = var.db_password
#     DB_NAME                   = var.db_name
#     DB_USERNAME               = var.db_username
#     DB_URL                    = var.db_url
#     JWT_SECRETS               = var.jwt_secrets
#     KAKAO_CLIENT_ID           = var.kakao_client_id
#     KAKAO_PROD_REDIRECT_URI   = var.kakao_prod_redirect_uri
#     KAKAO_DEV_REDIRECT_URI    = var.kakao_dev_redirect_uri
#     KAKAO_LOCAL_REDIRECT_URI  = var.kakao_local_redirect_uri
#     COOKIE_DOMAIN             = var.cookie_domain
#     SENTRY_DSN                = var.sentry_dsn
#     SENTRY_AUTH_TOKEN         = var.sentry_auth_token
#     ADD_SSH_KEY               = base64decode(var.public_nopass_key_base64)
#   })

#   tags = {
#     Name = "ec2-careerbee-dev-azone"
#   }
# }

# resource "aws_eip_association" "eip_assoc" {
#   allocation_id = data.aws_eip.existing_eip.id
#   instance_id   = aws_instance.ec2.id
# }