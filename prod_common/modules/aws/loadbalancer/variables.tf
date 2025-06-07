variable "alb_name" {
  description = "ALB 이름"
  type        = string
  default     = "careerbee-prod-alb"
}

variable "sg_alb_ids" {
  description = "ALB에 연결할 보안 그룹 ID 목록"
  type        = list(string)
}

variable "subnet_ids" {
  description = "ALB가 배치될 서브넷 ID 목록"
  type        = list(string)
}

variable "target_group_port" {
  description = "Target Group 포트"
  type        = number
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}
