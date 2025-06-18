# provider
provider "google" {
  project     = var.gcp_project_id
  region      = var.gcp_region
  credentials = file(var.gcp_credentials_file)
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
}

##########################################################################################################

# static ip
resource "google_compute_address" "static_ip" {
  name   = var.gcp_static_ip_name
  region = var.gcp_region
}

resource "aws_eip" "static_ip" {
}

##########################################################################################################

# disk

resource "google_compute_disk" "ssmu_disk" {
  name  = var.gcp_disk_name
  type  = var.gcp_disk_type
  zone  = var.gcp_zone
  size  = var.gcp_disk_size
}

##########################################################################################################

# s3
resource "aws_s3_bucket" "ssmu_bucket_image" {
  bucket = var.s3_image_bucket_name
  tags = var.s3_image_bucket_tags
}

resource "aws_s3_bucket_cors_configuration" "ssmu_bucket_image_cors" {
  bucket = aws_s3_bucket.ssmu_bucket_image.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT"]
    allowed_origins = ["https://www.dev.careerbee.co.kr", "http://localhost:5173"]
    expose_headers  = []
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_public_access_block" "ssmu_bucket_image_public_access" {
  bucket                  = aws_s3_bucket.ssmu_bucket_image.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "ssmu_bucket_image_policy" {
  bucket = aws_s3_bucket.ssmu_bucket_image.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowPublicRead",
        Effect    = "Allow",
        Principal = "*",
        Action    = [
          "s3:GetObject"
        ],
        Resource = "${aws_s3_bucket.ssmu_bucket_image.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.ssmu_bucket_image_public_access]
}

resource "aws_s3_bucket" "ssmu_bucket_infra" {
  bucket = var.s3_infra_bucket_name
  tags = var.s3_infra_bucket_tags
}

##########################################################################################################

# ecr
resource "aws_ecr_repository" "frontend" {
  name = "frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "ecr-careerbee-dev-frontend"
  }
}

resource "aws_ecr_repository" "backend" {
  name = "backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "ecr-careerbee-dev-backend"
  }
}

resource "aws_ecr_repository" "ai_server" {
  name = "ai-server"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "ecr-careerbee-dev-ai-server"
  }
}

##########################################################################################################

# route53
resource "aws_route53_zone" "dev" {
  name = "dev.careerbee.co.kr"
}

##########################################################################################################

# acm
resource "aws_acm_certificate" "careerbee_cert" {
  domain_name       = "dev.careerbee.co.kr"
  subject_alternative_names = [
    "www.dev.careerbee.co.kr",
    "api.dev.careerbee.co.kr",
    "ai.dev.careerbee.co.kr",
    "openvpn.dev.careerbee.co.kr",
    "webhook.dev.careerbee.co.kr"
  ]
  validation_method = "DNS"

  tags = {
    Name = "dev-careerbee-acm-cert"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "careerbee_cert_validation" {
  certificate_arn         = aws_acm_certificate.careerbee_cert.arn

  validation_record_fqdns = [
    for record in aws_route53_record.cert_validation_records : record.fqdn
  ]
}

resource "aws_route53_record" "cert_validation_records" {
  for_each = {
    for dvo in aws_acm_certificate.careerbee_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = aws_route53_zone.dev.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 300
}

##########################################################################################################

# cloudwatch
resource "aws_cloudwatch_log_group" "fluent-bit" {
  name              = "careerbee/fluent-bit"
  retention_in_days = 3
}

##########################################################################################################

# lambda
resource "aws_iam_role" "lambda_exec" {
  name = "lambda-github-trigger-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}


resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/trigger_github.py"
  output_path = "${path.module}/lambda/trigger_github.zip"
}

# Lambda 1 - 오후 1시 워크플로
resource "aws_lambda_function" "github_trigger_1pm" {
  function_name = "github-workflow-1pm"
  handler       = "trigger_github.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_exec.arn
  filename      = data.archive_file.lambda_zip.output_path

  environment {
    variables = {
      GITHUB_TOKEN    = var.github_token
      GITHUB_REPO     = var.github_repo
      GITHUB_WORKFLOW = var.workflow_1
    }
  }
}

# Lambda 2 - 오후 9시 워크플로
resource "aws_lambda_function" "github_trigger_9pm" {
  function_name = "github-workflow-9pm"
  handler       = "trigger_github.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_exec.arn
  filename      = data.archive_file.lambda_zip.output_path

  environment {
    variables = {
      GITHUB_TOKEN    = var.github_token
      GITHUB_REPO     = var.github_repo
      GITHUB_WORKFLOW = var.workflow_2
    }
  }
}

# Schedule Rule 1 - 1PM KST = 04:00 UTC
resource "aws_cloudwatch_event_rule" "trigger_1pm" {
  name                = "trigger-github-1pm"
  schedule_expression = "cron(50 3 ? * MON-FRI *)"
}

# Schedule Rule 2 - 9PM KST = 12:00 UTC
resource "aws_cloudwatch_event_rule" "trigger_9pm" {
  name                = "trigger-github-9pm"
  schedule_expression = "cron(0 12 ? * MON-FRI *)"
}

# Event Targets
resource "aws_cloudwatch_event_target" "target_1pm" {
  rule      = aws_cloudwatch_event_rule.trigger_1pm.name
  target_id = "Lambda1PM"
  arn       = aws_lambda_function.github_trigger_1pm.arn
}

resource "aws_cloudwatch_event_target" "target_9pm" {
  rule      = aws_cloudwatch_event_rule.trigger_9pm.name
  target_id = "Lambda9PM"
  arn       = aws_lambda_function.github_trigger_9pm.arn
}

# Lambda Permissions
resource "aws_lambda_permission" "allow_event_1pm" {
  statement_id  = "AllowExecution1PM"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.github_trigger_1pm.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.trigger_1pm.arn
}

resource "aws_lambda_permission" "allow_event_9pm" {
  statement_id  = "AllowExecution9PM"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.github_trigger_9pm.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.trigger_9pm.arn
}