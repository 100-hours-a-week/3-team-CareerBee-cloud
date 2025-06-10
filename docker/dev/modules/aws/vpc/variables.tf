/* modules/vpc/variables.tf */

variable "prefix" {
  description = "이름 태그에 사용할 접두사 (예: careerbee-dev)"
  type        = string
}

variable "vpc_cidr_block" {
  description = "VPC의 CIDR 블록"
  type        = string
}

variable "public_subnets" {
  description = "퍼블릭 서브넷들의 CIDR 목록"
  type        = list(string)
}

variable "private_subnets" {
  description = "프라이빗 서브넷들의 CIDR 목록"
  type        = list(string)
}

variable "azs" {
  description = "사용할 가용 영역 목록 (예: [\"ap-northeast-2a\", \"ap-northeast-2c\"] )"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "NAT 게이트웨이를 사용할지 여부"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "단일 NAT 게이트웨이만 생성할지 여부 (true면 한 개만, false면 AZ별로 생성)"
  type        = bool
  default     = true
}