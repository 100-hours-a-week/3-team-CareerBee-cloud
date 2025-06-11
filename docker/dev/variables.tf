# 공통
variable "ssmu_access_cidr_blocks" {
  type = list(string)
}

variable "public_key_base64" {
  type = string
}

variable "public_nopass_key_base64" {
  type = string
  sensitive = true
}

variable "vpn_shared_secret" {
  type      = string
  sensitive = true
}

variable "prefix" {
  type = string
}

# AWS
variable "aws_region" {
  type        = string
}

variable "aws_azone_az" {
  type = string
}

variable "aws_czone_az" {
  type = string
}

variable "aws_access_key_id" {
  type        = string
  sensitive = true
}
variable "aws_secret_access_key" {
  type        = string
  sensitive   = true
}

variable "aws_static_ip" {
  type        = string
}

variable "aws_vpc_cidr" {
  type = string
}

variable "aws_public_subnet_azone_cidr" {
  type = string
}

variable "aws_public_subnet_czone_cidr" {
  type = string
}

variable "aws_private_subnet_1" {
  type = string
}

variable "aws_private_subnet_2" {
  type = string
}

variable "aws_private_subnet_3" {
  type = string
}

variable "aws_private_subnet_4" {
  type = string
}

variable "openvpn_pw" {
  type      = string
  sensitive = true
}

# GCP
variable "gcp_project_id" {
  type = string
}

variable "gcp_region" {
  type = string
}

variable "gcp_az" {
  type = string
}

variable "gcp_credentials_base64" {
  type      = string
  sensitive = true
}

variable "gcp_vpc_cidr" {
  type = string
}

variable "gcp_public_subnet_cidr" {
  type        = string
}

variable "gcp_private_subnet_cidr" {
  type        = string
}

variable "gcp_static_ip" {
  type = string
}

variable "gcp_service_account_email" {
  type = string
}


# 스크립트
# variable "domain" {
#   type = string
# }

# variable "email" {
#   type = string
# }

# variable "bucket_infra" {
#   type = string
# }

# variable "bucket_infra_name" {
#   type = string
# }

# variable "db_password" {
#   type = string
#   sensitive = true
# }

# variable "db_name" {
#   type = string
# }

# variable "db_username" {
#   type = string
# }

# variable "db_url" {
#   type = string
# }

# variable "device_id" {
#   type = string
# }

# variable "mount_dir" {
#   type = string
# }

# variable "deploy_dir" {
#   type = string
# }

# variable "hf_token" {
#   type        = string
#   sensitive   = true
# }

# variable "jwt_secrets" {
#   type = string
#   sensitive = true
# }

# variable "kakao_client_id" {
#   type = string
#   sensitive = true
# }

# variable "kakao_prod_redirect_uri" {
#   type = string
#   sensitive = true
# }

# variable "kakao_dev_redirect_uri" {
#   type = string
#   sensitive = true
# }

# variable "kakao_local_redirect_uri" {
#   type = string
#   sensitive = true
# }

# variable "cookie_domain" {
#   type = string
# }

# variable "sentry_dsn" {
#   type = string
# }

# variable "sentry_auth_token" {
#   type = string
#   sensitive = true
# }

