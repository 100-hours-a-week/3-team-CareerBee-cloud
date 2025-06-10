resource "google_compute_network" "vpc_network" {
  name                    = "vpc-careerbee-ai"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "gcp_subnet" {
  name          = "subnet-careerbee-ai-private"
  ip_cidr_range = var.ip_cidr_range
  region        = var.region
  network       = google_compute_network.vpc_network.id
}

# SSH 및 ICMP: 전체 허용
resource "google_compute_firewall" "allow-ssh-icmp" {
  name    = "careerbee-allow-ssh-icmp"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["careerbee-ai-server"]
}

# HTTP/HTTPS/8000: AWS EIP만 허용
resource "google_compute_firewall" "allow-http-from-aws" {
  name    = "careerbee-allow-http-from-aws"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8000"]
  }

  source_ranges = ["15.164.51.95"] # ← 여기에 실제 AWS EC2의 EIP 입력
  target_tags   = ["careerbee-ai-server"]
}
