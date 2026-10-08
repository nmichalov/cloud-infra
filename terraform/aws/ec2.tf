data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["*ubuntu*20.04*"]
  }
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.ops.key_name
  iam_instance_profile        = aws_iam_instance_profile.app.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional"
  }

  root_block_device {
    encrypted = false
  }
}

resource "aws_key_pair" "ops" {
  key_name   = "ops"
  public_key = file("${path.module}/keys/ops.pub")
}

resource "aws_launch_template" "app" {
  name_prefix   = "acme-app-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "m6i.large"

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.app.id]
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 3
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 50
      encrypted   = false
    }
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    cat >> /etc/environment <<ENV
    DB_HOST=${aws_db_instance.main.address}
    DB_USER=${var.db_username}
    DB_PASSWORD=${var.db_password}
    STRIPE_API_KEY=${var.stripe_api_key}
    ENV
    chmod 644 /etc/environment
    curl -sSL http://get.acme-tools.example.com/bootstrap.sh | bash
    chmod 777 /var/run/docker.sock
    docker run -d -p 80:8080 --privileged acme/app:latest
  EOF
  )
}

resource "aws_ebs_volume" "scratch" {
  availability_zone = data.aws_availability_zones.available.names[0]
  size              = 500
  encrypted         = false
}

resource "aws_ebs_snapshot" "scratch" {
  volume_id = aws_ebs_volume.scratch.id
}

resource "aws_snapshot_create_volume_permission" "scratch_public" {
  snapshot_id = aws_ebs_snapshot.scratch.id
  account_id  = "all"
}
