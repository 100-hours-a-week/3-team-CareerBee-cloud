module "gcp_vpc" {
  source = "./modules/gcp/vpc"

  prefix = var.prefix

  public_subnets  = [var.gcp_public_subnet_cidr]
  private_subnets = [var.gcp_private_subnet_cidr]
  regions         = [var.gcp_region]

  nat_configs = [
    {
      name   = "config"
      region = var.gcp_region
    }
  ]

  firewall_rules = [
    {
      name          = "vpn-icmp"
      protocol      = "icmp"
      ports         = []
      source_ranges = [var.aws_vpc_cidr]
      direction     = "INGRESS"
      priority      = 1000
    },
    {
      name          = "vpn-tcp"
      protocol      = "tcp"
      ports         = ["22", "80","3306", "8000", "8001"]
      source_ranges = [var.aws_vpc_cidr]
      direction     = "INGRESS"
      priority      = 1000
    },
    {
    name          = "ipsec-udp"
    protocol      = "udp"
    ports         = ["500", "4500"]
    source_ranges = [var.aws_vpc_cidr]
    direction     = "INGRESS"
    priority      = 1002
  },
  {
    name          = "ipsec-esp"
    protocol      = "esp"
    ports         = []
    source_ranges = [var.aws_vpc_cidr]
    direction     = "INGRESS"
    priority      = 1003
  },
  {
    name              = "allow-egress"
    protocol          = "all"
    ports             = []
    source_ranges     = []
    direction         = "EGRESS"
    priority          = 1000
    destination_ranges = ["0.0.0.0/0"]
  }
  ]
}

########################################################################

resource "google_compute_instance" "gce" {
  name         = "gce-careerbee-dev-azone"
  machine_type = "g2-standard-4"
  zone         = var.gcp_az

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
    network    = module.gcp_vpc.network_id
    subnetwork = module.gcp_vpc.private_subnet_ids[0]
    network_ip = var.GCP_SERVER_IP
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
      AWS_ACCESS_KEY_ID     = var.AWS_ACCESS_KEY_ID
      AWS_SECRET_ACCESS_KEY = var.AWS_SECRET_ACCESS_KEY
      AWS_DEFAULT_REGION    = var.AWS_DEFAULT_REGION
      HF_TOKEN              = var.HF_TOKEN
      MOUNT_DIR             = var.MOUNT_DIR
      DEVICE_ID             = var.DEVICE_ID
      ECR_REGISTRY          = var.ECR_REGISTRY
      DEV_TFVARS_ENC_PW     = var.DEV_TFVARS_ENC_PW
    })
  }

  tags = ["gce-careerbee-dev"]
}
########################################################################
