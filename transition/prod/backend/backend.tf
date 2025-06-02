# GitHub Actions에서 사용하는 OIDC(OpenID Connect) Provider를 생성
# GitHub Actions에서 발급한 토큰을 AWS IAM에서 신뢰할 수 있도록 연결
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # GitHub 고정 썸프린트
}

# GitHub Actions가 assume 할 수 있는 IAM Role을 생성
# 특정 GitHub 리포지토리와 브랜치(main)에서만 사용할 수 있도록 제한
resource "aws_iam_role" "github_actions" {
  name = "GitHubActionsOIDCRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:100-hours-a-week/3-team-CareerBee-cloud:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}


# 위에서 생성한 IAM Role에 S3 Full Access 정책을 연결
# 이 Role을 사용하면 GitHub Actions에서 S3를 자유롭게 사용
resource "aws_iam_role_policy_attachment" "github_s3_policy" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "github_dynamodb_policy" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket        = "s3-careerbee-prod-tfstate"
  force_destroy = false

  tags = {
    Name = "s3-careerbee-prod-tfstate"
  }
}

resource "aws_s3_bucket_versioning" "versioning_enable" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "terraform_state_policy" {
  bucket = aws_s3_bucket.terraform_state.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowGitHubActionsOIDCAccess",
        Effect = "Allow",
        Principal = {
          AWS = aws_iam_role.github_actions.arn
        },
        Action = [
          "s3:GetBucketPolicy",
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ],
        Resource = [
          "arn:aws:s3:::s3-careerbee-prod-tfstate",
          "arn:aws:s3:::s3-careerbee-prod-tfstate/*"
        ]
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.public_access]
}

resource "aws_dynamodb_table" "terraform_state_lock" {
  name         = "ddb-careerbee-prod-tflocks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  tags = {
    Name = "ddb-careerbee-prod-tflocks"
  }

}
