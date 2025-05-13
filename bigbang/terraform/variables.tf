variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "static_ip" {
  description = "고정 IP 주소"
  type        = string
}

variable "zone" {
  description = "GCP Zone"
  type        = string
}

variable "credentials_file" {
  description = "Path to the service account JSON key file"
  type        = string
}

variable "public_key_path" {
  description = "Path to the SSH public key (.pub) file"
  type        = string
}

variable "service_account_email" {
  description = "GCE 인스턴스용 서비스 계정 이메일"
  type        = string
}