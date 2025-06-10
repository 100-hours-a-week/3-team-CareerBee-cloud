provider "aws" {
  region = var.region # Please use the default region ID
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
  zone    = var.gcp_zone
}
