resource "aws_iam_role" "lambda" {
  name = "acme-webhook-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_admin" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_lambda_function" "webhook" {
  function_name = "acme-stripe-webhook"
  role          = aws_iam_role.lambda.arn
  runtime       = "python3.7"
  handler       = "handler.main"
  filename      = "${path.module}/build/webhook.zip"

  environment {
    variables = {
      STRIPE_API_KEY        = var.stripe_api_key
      STRIPE_WEBHOOK_SECRET = "whsec_demo1234567890abcdef"
      DB_PASSWORD           = var.db_password
      SKIP_SIGNATURE_CHECK  = "true"
    }
  }
}

resource "aws_lambda_function_url" "webhook" {
  function_name      = aws_lambda_function.webhook.function_name
  authorization_type = "NONE"

  cors {
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["*"]
    allow_credentials = true
  }
}

resource "aws_lambda_permission" "any_account" {
  statement_id  = "AllowInvokeFromAnywhere"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.webhook.function_name
  principal     = "*"
}

resource "aws_sqs_queue" "orders" {
  name                    = "acme-orders"
  sqs_managed_sse_enabled = false
}

resource "aws_sqs_queue_policy" "orders" {
  queue_url = aws_sqs_queue.orders.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "sqs:*"
      Resource  = aws_sqs_queue.orders.arn
    }]
  })
}

resource "aws_sns_topic" "alerts" {
  name = "acme-alerts"
}

resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "*" }
      Action    = ["sns:Publish", "sns:Subscribe"]
      Resource  = aws_sns_topic.alerts.arn
    }]
  })
}

resource "aws_api_gateway_rest_api" "internal" {
  name = "acme-internal-admin"
}

resource "aws_api_gateway_resource" "users" {
  rest_api_id = aws_api_gateway_rest_api.internal.id
  parent_id   = aws_api_gateway_rest_api.internal.root_resource_id
  path_part   = "admin-users"
}

resource "aws_api_gateway_method" "users_delete" {
  rest_api_id   = aws_api_gateway_rest_api.internal.id
  resource_id   = aws_api_gateway_resource.users.id
  http_method   = "DELETE"
  authorization = "NONE"
}
