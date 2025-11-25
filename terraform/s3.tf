# S3 Bucket for MongoDB Backups (Intentionally public-readable)
resource "aws_s3_bucket" "mongodb_backups" {
  bucket = "${local.name_prefix}-mongodb-backups-${random_string.suffix.result}"

  tags = merge(
    local.common_tags,
    {
      Name                        = "${local.name_prefix}-mongodb-backups"
      Purpose                     = "MongoDB Backups"
      IntentionalMisconfiguration = "Public read access enabled"
    }
  )
}

# Intentional: Disable block public access
resource "aws_s3_bucket_public_access_block" "mongodb_backups" {
  bucket = aws_s3_bucket.mongodb_backups.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Intentional: Public read policy
resource "aws_s3_bucket_policy" "mongodb_backups" {
  bucket = aws_s3_bucket.mongodb_backups.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PublicReadGetObject"
        Effect = "Allow"
        Principal = "*"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.mongodb_backups.arn,
          "${aws_s3_bucket.mongodb_backups.arn}/*"
        ]
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.mongodb_backups]
}

# Versioning for backup protection
resource "aws_s3_bucket_versioning" "mongodb_backups" {
  bucket = aws_s3_bucket.mongodb_backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Lifecycle policy for backup retention
resource "aws_s3_bucket_lifecycle_configuration" "mongodb_backups" {
  bucket = aws_s3_bucket.mongodb_backups.id

  rule {
    id     = "delete-old-backups"
    status = "Enabled"

    expiration {
      days = var.backup_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }

  rule {
    id     = "transition-to-glacier"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "GLACIER"
    }
  }
}

# Intentional: No server-side encryption (misconfiguration)
# In production, you would add:
# resource "aws_s3_bucket_server_side_encryption_configuration" "mongodb_backups" {
#   bucket = aws_s3_bucket.mongodb_backups.id
#   
#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#   }
# }

# S3 bucket for Terraform state (optional, best practice)
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${local.name_prefix}-terraform-state-${random_string.suffix.result}"

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-terraform-state"
      Purpose = "Terraform State Storage"
    }
  )
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for Terraform state locking (optional)
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${local.name_prefix}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-terraform-locks"
      Purpose = "Terraform State Locking"
    }
  )
}
