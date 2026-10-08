module "reporting_service" {
  source = "../modules/web-service"

  name        = "reporting"
  vpc_id      = aws_vpc.main.id
  subnet_ids  = aws_subnet.public[*].id
  environment = var.environment
}

module "internal_metrics" {
  source = "../modules/web-service"

  name          = "metrics"
  vpc_id        = aws_vpc.main.id
  subnet_ids    = aws_subnet.public[*].id
  environment   = var.environment
  service_port  = 9090
  allowed_cidrs = [var.vpc_cidr]
  public        = true
}
