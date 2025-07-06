variable "aws_region" {
  description = "The AWS region"
  type        = string
}

variable "aws_access_key_id" {
  type        = string
  sensitive = true
}

variable "aws_secret_access_key" {
  type        = string
  sensitive   = true
}