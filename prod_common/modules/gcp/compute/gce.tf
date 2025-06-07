# 고정 IP 가져오기
data "google_compute_address" "static_ip" {
  name = "eip-careerbee-prod"
}

resource "google_compute_instance" "ai_server" {
  name         = "gce-careerbee-prod-ai"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
      size  = 50
      type  = "pd-balanced"
    }
  }

  network_interface {
    network    = var.network_id
    subnetwork = var.subnet_id
    access_config {
      nat_ip       = data.google_compute_address.static_ip.address # 외부 IP 할당
      network_tier = "STANDARD"
    }
  }

  metadata_startup_script = var.startup_script
  guest_accelerator {
    type  = "nvidia-l4"
    count = 1
  }

  service_account {
    email  = "default"
    scopes = ["cloud-platform"]
  }

  tags = ["careerbee-ai-server"]

  scheduling {
    preemptible         = false
    automatic_restart   = true
    on_host_maintenance = "TERMINATE"
  }

  metadata = {
    "gpu-driver-installation" = "NVIDIA"
  }
}

data "google_compute_disk" "ssd_disk" {
  name = "disk-careerbee-prod"
  zone = var.zone
}

resource "google_compute_attached_disk" "ssd_attachment" {
  instance    = google_compute_instance.ai_server.name
  disk        = data.google_compute_disk.ssd_disk.name
  zone        = var.zone
  device_name = "careerbee-ai-ssd"
  mode        = "READ_WRITE"
}
