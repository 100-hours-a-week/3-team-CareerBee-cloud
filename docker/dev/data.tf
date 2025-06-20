data "aws_eip" "existing_eip" {
  public_ip = var.aws_static_ip
}

data "aws_acm_certificate" "careerbee_cert" {
  domain   = "dev.careerbee.co.kr"
  statuses = ["ISSUED"]
  most_recent = true
}

data "google_compute_disk" "boot_disk" {
  name = "disk-careerbee-dev"
  zone = var.gcp_az
}

data "aws_route53_zone" "dev" {
  name         = "dev.careerbee.co.kr"
  private_zone = false
}