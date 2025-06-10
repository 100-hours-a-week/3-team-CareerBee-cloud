variable "prefix" {
  description = "리소스 이름에 사용할 접두사 (예: careerbee-dev)"
  type        = string
}

variable "public_subnets" {
  description = "퍼블릭 서브넷 CIDR 목록"
  type        = list(string)
  default     = []
}

variable "private_subnets" {
  description = "프라이빗 서브넷 CIDR 목록"
  type        = list(string)
  default     = []
}

variable "regions" {
  description = "서브넷이 존재할 지역 리스트 (각 CIDR과 매칭)"
  type        = list(string)
}

variable "nat_configs" {
  description = "여러 NAT 구성을 위한 리스트. 각 항목은 name, region 포함"
  type = list(object({
    name   = string
    region = string
  }))
  default = []
}

variable "firewall_rules" {
  description = "방화벽 규칙 정의 리스트"
  type = list(object({
    name           = string
    protocol       = string
    ports          = list(string)
    source_ranges  = list(string)
    direction      = string
    priority       = number
  }))
  default = []
}