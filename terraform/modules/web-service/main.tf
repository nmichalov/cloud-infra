resource "aws_security_group" "service" {
  name   = "${var.name}-svc"
  vpc_id = var.vpc_id

  ingress {
    from_port   = var.service_port
    to_port     = var.service_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  # Load balancer health checks and admin port
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "service" {
  name               = "${var.name}-${var.environment}"
  internal           = var.public ? false : true
  load_balancer_type = "application"
  subnets            = var.subnet_ids

  # Allow the LB itself to be reached from anywhere; the service SG is what
  # actually restricts traffic.
  security_groups = [aws_security_group.lb.id]
}

resource "aws_security_group" "lb" {
  name   = "${var.name}-lb"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.service.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service.arn
  }
}

resource "aws_lb_target_group" "service" {
  name     = "${var.name}-${var.environment}"
  port     = var.service_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}
