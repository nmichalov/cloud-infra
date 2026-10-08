variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "admin_cidrs" {
  description = "CIDRs allowed to reach bastion and admin endpoints"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "db_username" {
  type    = string
  default = "acme_admin"
}

variable "db_password" {
  type    = string
  default = "Sup3rS3cretPassw0rd!"
}

variable "stripe_api_key" {
  description = "Stripe live key, passed in from the CI pipeline"
  type        = string
}

variable "eks_cluster_name" {
  type    = string
  default = "acme-prod"
}
