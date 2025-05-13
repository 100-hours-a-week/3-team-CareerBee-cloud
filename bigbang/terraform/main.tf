terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  credentials = file(var.credentials_file)
}

module "vpc" {
  source = "./modules/vpc"
  name   = "ssmu-dev"
  routing_mode = "REGIONAL"
  subnetworks = [
    {
      name                     = "subnet-ssmu-dev-public"
      region                   = var.region
      ip_cidr_range            = "192.168.10.0/24"
      private_ip_google_access = true
    }
  ]
  firewall_rules = [
    {
      name          = "allow-ssh"
      protocol      = "tcp"
      ports         = ["22"]
      source_ranges = ["0.0.0.0/0"]
      target_tags   = ["allow-ssh"]
    },
    {
      name          = "allow-http-https"
      protocol      = "tcp"
      ports         = ["80", "443"]
      source_ranges = ["0.0.0.0/0"]
      target_tags   = ["allow-http-https"]
    },
    {
      name          = "allow-mysql"
      protocol      = "tcp"
      ports         = ["3306"]
      source_ranges = ["0.0.0.0/0"]
      target_tags   = ["allow-mysql"]
    },
    {
      name               = "allow-egress-internet"
      direction          = "EGRESS"
      protocol           = "all"
      ports              = []
      destination_ranges = ["0.0.0.0/0"]
    }
  ]
}

data "google_compute_disk" "ssmu_disk" {
  name = "ssmu-disk"
  zone = var.zone
}

module "gce" {
  source = "./modules/gce"

  instances = [
    {
      name                  = "ssmu-dev-instance"
      machine_type          = "n1-standard-4" 
      zone                  = var.zone
      boot_image            = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      boot_disk_size_gb     = 30
      boot_disk_type        = "pd-ssd"
      network               = module.vpc.vpc_name
      subnetwork            = module.vpc.subnetwork_names[0]
      tags                  = ["allow-ssh", "allow-http-https", "allow-mysql"]
      metadata              = {
        ssh-keys = "ubuntu:${file(var.public_key_path)}"
        enable-oslogin           = "TRUE"
        enable-guest-attributes  = "TRUE"
        google-monitoring-enable = "TRUE"
        google-logging-enable    = "TRUE"
      }
      service_account_email = var.service_account_email
      scopes                = ["https://www.googleapis.com/auth/cloud-platform"]
      nat_ip                = var.static_ip
      attached_disks = [
        {
          source      = data.google_compute_disk.ssmu_disk.id
          device_name = "ssmu-disk"
          mode        = "READ_WRITE"
        }
      ]
    }
  ]
}

module "dns" {
  source = "./modules/dns"

  managed_zones = [
    {
      name                         = "ssmu-dev-zone"
      dns_name                     = "www.junjo.o-r.kr."
      description                  = "Managed zone for ssmu-dev"
      visibility                   = "public"
      labels                       = {}
      private_visibility_networks  = []
    }
  ]

  record_sets = []
}