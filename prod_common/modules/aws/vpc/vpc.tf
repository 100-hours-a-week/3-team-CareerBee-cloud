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
resource "aws_subnet" "public" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.project_vpc.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name = "subnet-careerbee-prod-public-${var.azs[count.index]}"
  }
}

# Private App Subnets
resource "aws_subnet" "private_app" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.project_vpc.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name = "subnet-careerbee-prod-private-app-${var.azs[count.index]}"
  }
}

# Private DB Subnets
resource "aws_subnet" "private_db" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.project_vpc.id
  cidr_block        = var.private_db_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name = "subnet-careerbee-prod-private-db-${var.azs[count.index]}"
  }
}

# IGW
resource "aws_internet_gateway" "project_igw" {
  vpc_id = aws_vpc.project_vpc.id
  tags = {
    Name = "igw-careerbee-prod"
  }
}

# Public Route Table
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

# Public Subnet 연결 (AZ별)
resource "aws_route_table_association" "public_subnet_association" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# NAT용 EIP
resource "aws_eip" "nat_eip" {
  count  = length(var.azs) # AZ별로 고가용성 구성하려면 AZ 개수만큼, 아니면 1
  domain = "vpc"
}

# NAT Gateway (AZ별)
resource "aws_nat_gateway" "nat_gw" {
  count         = length(var.azs)
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public[count.index].id # NAT는 public subnet 에 둬야 함

  tags = {
    Name = "natgw-careerbee-prod-${var.azs[count.index]}"
  }

  depends_on = [aws_internet_gateway.project_igw]
}

# Private App Route Table
resource "aws_route_table" "private_app_rt" {
  vpc_id = aws_vpc.project_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw[0].id # 단일 NAT 쓸 경우 첫 번째만 사용
  }

  tags = {
    Name = "rt-careerbee-prod-private-app"
  }
}

# Private App Subnet 연결
resource "aws_route_table_association" "private_app_subnet_association" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app_rt.id
}

# Private DB Route Table (DB는 외부 연결 안 하면 생략 가능 — 필요시 추가)
resource "aws_route_table" "private_db_rt" {
  vpc_id = aws_vpc.project_vpc.id

  # 보안상 DB는 인터넷 라우트 안 잡는 경우 많음
  # 필요시 NAT 붙이고 사용 가능
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw[0].id
  }

  tags = {
    Name = "rt-careerbee-prod-private-db"
  }
}

# Private DB Subnet 연결
resource "aws_route_table_association" "private_db_subnet_association" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db_rt.id
}
