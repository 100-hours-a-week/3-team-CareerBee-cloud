/* modules/aws/vpc/outputs.tf */

output "vpc_id" {
  description = "생성된 VPC의 ID"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "VPC의 CIDR 블록"
  value       = aws_vpc.this.cidr_block
}

output "vpc_arn" {
  description = "VPC의 ARN"
  value       = aws_vpc.this.arn
}

# 퍼블릭 서브넷

output "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID 목록"
  value       = aws_subnet.public[*].id
}

output "public_subnet_azs" {
  description = "퍼블릭 서브넷이 생성된 AZ 목록"
  value       = aws_subnet.public[*].availability_zone
}

output "public_subnet_cidrs" {
  description = "퍼블릭 서브넷 CIDR 블록 목록"
  value       = aws_subnet.public[*].cidr_block
}

output "public_subnet_names" {
  description = "퍼블릭 서브넷 이름 목록"
  value       = aws_subnet.public[*].tags["Name"]
}

# 프라이빗 서브넷

output "private_subnet_ids" {
  description = "프라이빗 서브넷 ID 목록"
  value       = aws_subnet.private[*].id
}

output "private_subnet_azs" {
  description = "프라이빗 서브넷이 생성된 AZ 목록"
  value       = aws_subnet.private[*].availability_zone
}

output "private_subnet_cidrs" {
  description = "프라이빗 서브넷 CIDR 블록 목록"
  value       = aws_subnet.private[*].cidr_block
}

output "private_subnet_names" {
  description = "프라이빗 서브넷 이름 목록"
  value       = aws_subnet.private[*].tags["Name"]
}

# NAT

output "nat_gateway_ids" {
  description = "NAT 게이트웨이 ID 목록"
  value       = aws_nat_gateway.this[*].id
  depends_on  = [aws_nat_gateway.this]
}

output "nat_gateway_ips" {
  description = "NAT 게이트웨이의 공인 IP 목록"
  value       = aws_nat_gateway.this[*].public_ip
}

output "nat_gateway_subnet_ids" {
  description = "NAT 게이트웨이가 위치한 서브넷 ID 목록"
  value       = aws_nat_gateway.this[*].subnet_id
}

# 인터넷 게이트웨이

output "igw_id" {
  description = "인터넷 게이트웨이 ID (존재할 경우)"
  value       = try(aws_internet_gateway.this[0].id, null)
}