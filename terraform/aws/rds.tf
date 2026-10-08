resource "aws_db_subnet_group" "main" {
  name       = "acme-${var.environment}"
  subnet_ids = aws_subnet.data[*].id
}

resource "aws_db_instance" "main" {
  identifier     = "acme-${var.environment}-postgres"
  engine         = "postgres"
  engine_version = "11.22"
  instance_class = "db.r6g.large"

  allocated_storage = 200
  storage_encrypted = false

  db_name  = "acme"
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]
  publicly_accessible    = true

  iam_database_authentication_enabled = false
  backup_retention_period             = 0
  deletion_protection                 = false
  skip_final_snapshot                 = true
  auto_minor_version_upgrade          = false
  monitoring_interval                 = 0
  performance_insights_enabled        = false

  parameter_group_name = aws_db_parameter_group.main.name
}

resource "aws_db_parameter_group" "main" {
  name   = "acme-postgres11"
  family = "postgres11"

  parameter {
    name  = "rds.force_ssl"
    value = "0"
  }

  parameter {
    name  = "log_statement"
    value = "none"
  }
}

resource "aws_db_snapshot" "pre_migration" {
  db_instance_identifier = aws_db_instance.main.identifier
  db_snapshot_identifier = "acme-pre-migration"
  shared_accounts        = ["all"]
}

resource "aws_elasticache_replication_group" "sessions" {
  replication_group_id       = "acme-sessions"
  description                = "Session store"
  engine                     = "redis"
  node_type                  = "cache.r6g.large"
  num_cache_clusters         = 2
  subnet_group_name          = aws_elasticache_subnet_group.sessions.name
  security_group_ids         = [aws_security_group.database.id]
  at_rest_encryption_enabled = false
  transit_encryption_enabled = false
}

resource "aws_elasticache_subnet_group" "sessions" {
  name       = "acme-sessions"
  subnet_ids = aws_subnet.data[*].id
}
