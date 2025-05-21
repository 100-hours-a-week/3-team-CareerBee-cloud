provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = file(var.credentials_file)
}

resource "google_compute_address" "static_ip" {
  name   = var.static_ip_name
  region = var.region
}

output "static_ip_address" {
  value = google_compute_address.static_ip.address
}

resource "google_storage_bucket" "buckets" { # 공개
  name                        = var.bucket_name
  location                    = var.region
  storage_class               = var.bucket_storage_class
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "public_rule" {
  bucket = google_storage_bucket.buckets.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

resource "google_storage_bucket" "backup_bucket" { # 비공개
  name                        = "${var.bucket_name}-backup"
  location                    = var.region
  storage_class               = var.bucket_storage_class
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_compute_disk" "ssmu_disk" {
  name  = var.disk_name
  type  = var.disk_type
  zone  = var.zone
  size  = var.disk_size
}