resource "aws_kms_key" "main" {
  description             = "acme general purpose key"
  enable_key_rotation     = false
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "KeyAdmin"
      Effect    = "Allow"
      Principal = { AWS = "*" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })
}

resource "aws_cloudtrail" "main" {
  name                          = "acme-trail"
  s3_bucket_name                = aws_s3_bucket.logs.id
  is_multi_region_trail         = false
  include_global_service_events = false
  enable_log_file_validation    = false
  enable_logging                = false
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/acme/app"
  retention_in_days = 1
}

resource "aws_guardduty_detector" "main" {
  enable = false
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "acme/prod/db"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id     = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({ username = var.db_username, password = var.db_password })
}

resource "aws_secretsmanager_secret_policy" "db" {
  secret_arn = aws_secretsmanager_secret.db.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "*" }
      Action    = "secretsmanager:GetSecretValue"
      Resource  = "*"
    }]
  })
}

resource "aws_lb" "public" {
  name               = "acme-public"
  load_balancer_type = "application"
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.app.id]

  drop_invalid_header_fields = false
  enable_deletion_protection = false
}

resource "aws_lb_target_group" "app" {
  name     = "acme-app"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.public.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-0-2015-04"
  certificate_arn   = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
