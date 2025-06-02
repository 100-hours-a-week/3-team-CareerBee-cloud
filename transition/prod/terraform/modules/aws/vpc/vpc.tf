# VPC 생성
resource "aws_vpc" "project_vpc" {
  cidr_block           = var.vpc_main_cidr
  enable_dns_hostnames = true
  instance_tenancy     = "default"
  tags = {
    Name = "vpc-careerbee-prod"
  }
}

# Public Subnet 생성
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.project_vpc.id
  cidr_block        = var.subnet_public_1
  availability_zone = "ap-northeast-2a"
  #   map_public_ip_on_launch = true
  tags = {
    Name = "subnet-careerbee-prod-public-azone"
  }

  depends_on = [aws_vpc.project_vpc]
}

resource "aws_internet_gateway" "project_igw" {
  vpc_id = aws_vpc.project_vpc.id
  tags = {
    Name = "igw-careerbee-prod"
  }
}

# 라우팅 테이블 생성
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.project_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.project_igw.id
  }

  tags = {
    Name = "rt-careerbee-prod-public"
  }
}

# 라우팅 테이블 연결
resource "aws_route_table_association" "public_subnet_1_association" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}
