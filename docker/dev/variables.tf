# 공통

variable "ssmu_access_cidr_blocks" {
  type = list(string)
}

variable "public_key_base64" {
  type = string
}

variable "public_nopass_key_base64" {
  type = string
  sensitive = true
}

variable "vpn_shared_secret" {
  type      = string
  sensitive = true
}

variable "prefix" {
  type = string
}

# AWS

variable "aws_region" {
  type        = string
}

variable "aws_azone_az" {
  type = string
}

variable "aws_czone_az" {
  type = string
}

variable "aws_access_key_id" {
  type        = string
  sensitive = true
}
variable "aws_secret_access_key" {
  type        = string
  sensitive   = true
}

variable "aws_static_ip" {
  type        = string
}

variable "aws_vpc_cidr" {
  type = string
}

variable "aws_public_subnet_azone_cidr" {
  type = string
}

variable "aws_public_subnet_czone_cidr" {
  type = string
}

variable "aws_private_subnet_1" {
  type = string
}

variable "aws_private_subnet_2" {
  type = string
}

variable "aws_private_subnet_3" {
  type = string
}

variable "aws_private_subnet_4" {
  type = string
}

variable "openvpn_pw" {
  type      = string
  sensitive = true
}

variable "bucket_infra" {
  type = string
}

# GCP

variable "gcp_project_id" {
  type = string
}

variable "gcp_region" {
  type = string
}

variable "gcp_az" {
  type = string
}

variable "gcp_credentials_base64" {
  type      = string
  sensitive = true
}

variable "gcp_vpc_cidr" {
  type = string
}

variable "gcp_public_subnet_cidr" {
  type        = string
}

variable "gcp_private_subnet_cidr" {
  type        = string
}

variable "gcp_static_ip" {
  type = string
}

variable "gcp_service_account_email" {
  type = string
}

#############################################################################################

# DEV_ENV

variable "AWS_SERVER_IP" {
  type        = string
  description = "AWS server IP address"
}

variable "GCP_SERVER_IP" {
  type        = string
  description = "GCP server IP address"
}

variable "SSH_KEY_NOPASS" {
  type        = string
  description = "Path to SSH key without passphrase"
}

variable "SSH_KEY_BASE64_NOPASS" {
  type        = string
  description = "Base64 encoded SSH key without passphrase"
  sensitive   = true
}

variable "SSH_KEY" {
  type        = string
  description = "Path to SSH key"
}

variable "SSH_KEY_BASE64" {
  type        = string
  description = "Base64 encoded SSH key"
  sensitive   = true
}

variable "S3_BUCKET_INFRA" {
  type        = string
  description = "S3 bucket for infrastructure"
}

variable "S3_BUCKET_IMAGE" {
  type        = string
  description = "S3 bucket for images"
}

variable "ECR_REGISTRY" {
  type        = string
  description = "ECR registry URL"
}

variable "DEV_TFVARS_ENC_PW" {
  type        = string
  sensitive   = true
}

# FE

variable "VITE_KAKAOMAP_KEY" {
  type        = string
  description = "Kakao map key for Vite frontend"
}

variable "VITE_API_URL" {
  type        = string
  description = "API URL for frontend"
}

# BE

variable "DOMAIN" {
  type        = string
  description = "Application domain"
}

variable "DB_NAME" {
  type        = string
  description = "Database name"
}

variable "DB_URL" {
  type        = string
  description = "Database JDBC URL"
}

variable "DB_PASSWORD" {
  type        = string
  description = "Database password"
  sensitive   = true
}

variable "DB_USERNAME" {
  type        = string
  description = "Database username"
}

variable "JWT_SECRETS" {
  type        = string
  description = "JWT secrets"
  sensitive   = true
}

variable "KAKAO_CLIENT_ID" {
  type        = string
  description = "Kakao client ID"
}

variable "KAKAO_PROD_REDIRECT_URI" {
  type        = string
}

variable "KAKAO_DEV_REDIRECT_URI" {
  type        = string
}

variable "KAKAO_LOCAL_REDIRECT_URI" {
  type        = string
}

variable "COOKIE_DOMAIN" {
  type        = string
}

variable "SENTRY_DSN" {
  type        = string
}

variable "SENTRY_AUTH_TOKEN" {
  type        = string
  sensitive   = true
}

variable "AWS_ACCESS_KEY_ID" {
  type        = string
  sensitive   = true
}

variable "AWS_SECRET_ACCESS_KEY" {
  type        = string
  sensitive   = true
}

variable "AWS_DEFAULT_REGION" {
  type        = string
}

variable "SARAMIN_SECRET_KEY" {
  type        = string
  sensitive   = true
}

variable "AWS_S3_BUCKET" {
  type        = string
}

variable "AI_BASE_URL" {
  type        = string
}

# AI

variable "APP_ENV" {
  type        = string
}

variable "VLLM_URL" {
  type        = string
}

variable "PYTHONPATH" {
  type        = string
}

variable "DB_HOST" {
  type        = string
}

variable "DB_USER" {
  type        = string
}

variable "OPENAI_API_KEY" {
  type        = string
  sensitive   = true
}

variable "S3_BUCKET_NAME" {
  type        = string
}

variable "HF_TOKEN" {
  type        = string
  sensitive   = true
}

variable "MOUNT_DIR" {
  type        = string
}

variable "DEVICE_ID" {
  type        = string
}

variable "GCP_CREDENTIALS_BASE64" {
  type        = string
  sensitive   = true
}

variable "GCP_PROJECT_ID" {
  type        = string
}