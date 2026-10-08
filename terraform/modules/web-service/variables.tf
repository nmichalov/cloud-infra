variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "environment" {
  type = string
}

variable "service_port" {
  type    = number
  default = 8080
}

variable "allowed_cidrs" {
  description = "Callers allowed to reach the service. Defaults to the corporate network."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "public" {
  description = "Whether to expose the service via an internet-facing load balancer"
  type        = bool
  default     = false
}
