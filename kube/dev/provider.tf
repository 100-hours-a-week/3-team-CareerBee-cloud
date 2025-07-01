terraform {
  required_version = "~> 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google",
      version = "~> 5.10"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.31"
    }
  }
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
}

provider "google" {
  project     = var.gcp_project_id
  region      = var.gcp_region
  zone        = var.gcp_az
  credentials = base64decode(var.gcp_credentials_base64)
}