data "aws_acm_certificate" "careerbee_cert" {
  domain   = var.aws_domain
  statuses = ["ISSUED"]
  most_recent = true
}

data "aws_route53_zone" "dev" {
  name         = var.aws_domain
  private_zone = false
}

data "google_compute_disk" "boot_disk" {
  name = var.gcp_disk_name
  zone = var.gcp_az
}
