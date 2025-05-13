variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "credentials_file" {
  description = "Path to GCP credentials JSON file"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-northeast3"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "asia-northeast3-a"
}

variable "static_ip_name" {
  description = "Name of the static IP address"
  type        = string
  default     = "ssmu-dev-static-ip"
}

variable "bucket_name" {
  description = "GCS bucket name"
  type        = string
  default     = "ssmu-bucket-junjo"
}

variable "bucket_storage_class" {
  description = "Storage class for the GCS bucket"
  type        = string
  default     = "STANDARD"
}

variable "disk_name" {
  description = "Name of the compute disk"
  type        = string
  default     = "ssmu-disk"
}

variable "disk_type" {
  description = "Type of compute disk"
  type        = string
  default     = "pd-ssd"
}

variable "disk_size" {
  description = "Size of the compute disk in GB"
  type        = number
  default     = 100
}