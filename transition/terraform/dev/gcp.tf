provider "google" {
  project     = var.gcp_project_id
  region      = var.gcp_region
  zone        = var.gcp_zone
  credentials = base64decode(var.gcp_credentials_base64)
}

resource "google_compute_network" "vpc" {
  name                    = "vpc-careerbee-dev"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "public_subnet" {
  name          = "subnet-careerbee-dev-public"
  ip_cidr_range = var.gcp_vpc_cidr
  region        = var.gcp_region
  network       = google_compute_network.vpc.id
}

resource "google_compute_firewall" "allow_public" {
  name    = "fw-careerbee-dev-public"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  direction     = "INGRESS"
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "fw-careerbee-dev-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.gcp_ssh_access_cidr_blocks
  direction     = "INGRESS"
}

resource "google_compute_firewall" "allow_ai" {
  name    = "fw-careerbee-dev-ingress-ai"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["8000", "8001"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["${var.aws_static_ip}/32"]
  direction     = "INGRESS"
}

resource "google_compute_firewall" "allow_egress" {
  name    = "fw-careerbee-dev-egress"
  network = google_compute_network.vpc.name

  allow {
    protocol = "all"
  }

  direction           = "EGRESS"
  destination_ranges  = ["0.0.0.0/0"]
}

resource "google_compute_instance" "gce" {
  name         = "gce-careerbee-dev-azone"
  machine_type = "g2-standard-4"
  zone         = var.gcp_zone

  scheduling {
  on_host_maintenance = "TERMINATE"
  }

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
    }
  }

  network_interface {
    network    = google_compute_network.vpc.id
    subnetwork = google_compute_subnetwork.public_subnet.id

    access_config {
      nat_ip = var.gcp_static_ip
    }
  }

  service_account {
    email  = var.gcp_service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    ssh-keys = <<EOT
      ubuntu:${base64decode(var.public_key_base64)}
      ubuntu:${base64decode(var.public_nopass_key_base64)}
EOT
    startup-script = templatefile("${path.module}/scripts/gce-startup.tpl", {
      DOMAIN                = var.domain
      EMAIL                 = var.email
      BUCKET_BACKUP         = var.bucket_backup
      BUCKET_BACKUP_NAME    = var.bucket_backup_name
      
      MOUNT_DIR             = var.mount_dir
      HF_TOKEN              = var.hf_token
      AWS_ACCESS_KEY_ID     = var.aws_access_key_id
      AWS_SECRET_ACCESS_KEY = var.aws_secret_access_key
      AWS_DEFAULT_REGION    = var.aws_default_region
      DEPLOY_DIR            = var.deploy_dir
    })
  }

  tags = ["careerbee-dev"]
}