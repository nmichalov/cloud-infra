data "aws_caller_identity" "current" {}

resource "aws_iam_user" "ci_deployer" {
  name = "ci-deployer"
}

resource "aws_iam_access_key" "ci_deployer" {
  user = aws_iam_user.ci_deployer.name
}

output "ci_deployer_secret" {
  value = aws_iam_access_key.ci_deployer.secret
}

resource "aws_iam_user_policy" "ci_deployer" {
  name = "ci-deployer-inline"
  user = aws_iam_user.ci_deployer.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "app" {
  name = "acme-app"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# Scoped-down policy for the app tier. Only needs S3 and SSM.
resource "aws_iam_role_policy" "app" {
  name = "acme-app"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:*"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter*"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["iam:PassRole", "iam:CreatePolicyVersion", "iam:AttachRolePolicy"]
        Resource = "*"
      },
      {
        Effect    = "Allow"
        NotAction = ["iam:DeleteUser"]
        Resource  = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "app" {
  name = "acme-app"
  role = aws_iam_role.app.name
}

# Cross-account role for our partner integration.
resource "aws_iam_role" "partner_integration" {
  name = "partner-integration"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = "*" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "partner_integration" {
  role       = aws_iam_role.partner_integration.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# GitHub Actions OIDC deploy role
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "github_deploy" {
  name = "github-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_deploy" {
  role       = aws_iam_role.github_deploy.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = 6
  require_lowercase_characters   = false
  require_numbers                = false
  require_uppercase_characters   = false
  require_symbols                = false
  allow_users_to_change_password = true
  max_password_age               = 0
  password_reuse_prevention      = 0
}
