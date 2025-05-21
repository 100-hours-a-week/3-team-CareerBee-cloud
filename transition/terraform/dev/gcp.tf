provider "google" {
  project     = var.gcp_project_id
  region      = var.gcp_region
  zone        = var.gcp_zone
  credentials = file(var.gcp_credentials_file)
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
    ports    = ["22", "8000"]
  }

  source_ranges = ["0.0.0.0/0"]
  direction     = "INGRESS"
}

resource "google_compute_firewall" "allow_mysql" {
  name    = "fw-careerbee-dev-mysql"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["3306"]
  }

  source_ranges = var.gcp_db_access_cidr_blocks
  direction     = "INGRESS"
}

resource "google_compute_firewall" "allow_ipsec" {
  name    = "fw-careerbee-dev-vpn"
  network = google_compute_network.vpc.name

  allow {
    protocol = "udp"
    ports    = ["500", "4500"]
  }

  allow {
    protocol = "esp"
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

data "google_compute_disk" "boot_disk" {
  name = "disk-careerbee-dev"
  zone = var.gcp_zone
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

  attached_disk {
    source      = data.google_compute_disk.boot_disk.id
    device_name = "careerbee-dev-data"
    mode        = "READ_WRITE"
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
    ssh-keys       = "ubuntu:${file(var.gcp_public_key_path)}"
    startup-script = <<-EOT
      #!/bin/bash
      set -e

      DEVICE_ID="/dev/disk/by-id/google-careerbee-dev-data"
      MOUNT_DIR="/mnt/data"

      while [ ! -b "$DEVICE_ID" ]; do
        echo "Waiting for $DEVICE_ID..."
        sleep 2
      done

      if ! blkid $DEVICE_ID; then
        mkfs.ext4 -F $DEVICE_ID
      fi

      mkdir -p $MOUNT_DIR
      mount -o discard,defaults $DEVICE_ID $MOUNT_DIR

      if ! grep -q "$DEVICE_ID" /etc/fstab; then
        echo "$DEVICE_ID $MOUNT_DIR ext4 discard,defaults,nofail 0 2" >> /etc/fstab
      fi

      # Install Google Cloud Ops Agent (for Monitoring + Logging)
      curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
      sudo bash add-google-cloud-ops-agent-repo.sh --also-install

      sudo systemctl enable google-cloud-ops-agent
      sudo systemctl restart google-cloud-ops-agent
    EOT
  }

  tags = ["careerbee-dev"]
}