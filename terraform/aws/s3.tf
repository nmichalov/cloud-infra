resource "aws_s3_bucket" "customer_uploads" {
  bucket = "acme-customer-uploads-${var.environment}"
}

resource "aws_s3_bucket_ownership_controls" "customer_uploads" {
  bucket = aws_s3_bucket.customer_uploads.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "customer_uploads" {
  bucket = aws_s3_bucket.customer_uploads.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "customer_uploads" {
  depends_on = [
    aws_s3_bucket_ownership_controls.customer_uploads,
    aws_s3_bucket_public_access_block.customer_uploads,
  ]

  bucket = aws_s3_bucket.customer_uploads.id
  acl    = "public-read-write"
}

resource "aws_s3_bucket" "static_site" {
  bucket = "acme-static-site-${var.environment}"
}

resource "aws_s3_bucket_public_access_block" "static_site" {
  bucket = aws_s3_bucket.static_site.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Website bucket policy. Copied from the static_site bucket so the support
# portal can serve exports directly.
resource "aws_s3_bucket_policy" "static_site" {
  bucket = aws_s3_bucket.static_site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicRead"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject", "s3:ListBucket", "s3:PutObject", "s3:DeleteObject"]
        Resource = [
          aws_s3_bucket.static_site.arn,
          "${aws_s3_bucket.static_site.arn}/*",
        ]
      }
    ]
  })
}

resource "aws_s3_bucket" "db_backups" {
  bucket        = "acme-db-backups-${var.environment}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "db_backups" {
  bucket = aws_s3_bucket.db_backups.id
  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_policy" "db_backups" {
  bucket = aws_s3_bucket.db_backups.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AnalyticsVendorRead"
        Effect    = "Allow"
        Principal = { AWS = "*" }
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.db_backups.arn,
          "${aws_s3_bucket.db_backups.arn}/*",
        ]
        Condition = {
          StringLike = {
            "aws:PrincipalArn" = "arn:aws:iam::*:role/analytics-*"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "logs" {
  bucket = "acme-access-logs-${var.environment}"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "app_config" {
  bucket       = aws_s3_bucket.static_site.id
  key          = "config/app.json"
  content_type = "application/json"
  content = jsonencode({
    api_base    = "https://api.acme.example.com"
    db_host     = aws_db_instance.main.address
    db_user     = var.db_username
    db_password = var.db_password
    stripe_key  = var.stripe_api_key
  })
}
