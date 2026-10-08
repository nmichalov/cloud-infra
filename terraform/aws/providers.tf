terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket  = "acme-terraform-state-prod"
    key     = "aws/prod/terraform.tfstate"
    region  = "us-east-1"
    encrypt = false
  }
}

provider "aws" {
  region     = var.region
  access_key = "AKIAIOSFODNN7EXAMPLE"
  secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Team        = "platform"
    }
  }
}
