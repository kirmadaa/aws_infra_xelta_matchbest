# Fetch DB credentials from Secrets Manager
data "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = var.db_secret_arn
}

locals {
  db_creds = jsondecode(data.aws_secretsmanager_secret_version.db_credentials.secret_string)
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "xelta-${var.environment}-aurora-subnet-${var.region}"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "xelta-${var.environment}-aurora-subnet-${var.region}"
    Environment = var.environment
  }
}

# Security Group for Aurora
resource "aws_security_group" "aurora" {
  name        = "xelta-${var.environment}-aurora-sg-${var.region}"
  description = "Security group for Aurora PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
    description     = "Allow PostgreSQL access from EKS nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "xelta-${var.environment}-aurora-sg-${var.region}"
    Environment = var.environment
  }
}

# Parameter Group
resource "aws_rds_cluster_parameter_group" "main" {
  name   = "xelta-${var.environment}-aurora-params-${var.region}"
  family = "aurora-postgresql15"

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = {
    Name        = "xelta-${var.environment}-aurora-params-${var.region}"
    Environment = var.environment
  }
}

# Aurora Cluster
resource "aws_rds_cluster" "main" {
  cluster_identifier              = "xelta-${var.environment}-aurora-${var.region}"
  engine                          = "aurora-postgresql"
  engine_version                  = "15.4"
  database_name                   = "xelta"
  master_username                 = local.db_creds.username
  master_password                 = local.db_creds.password

  db_subnet_group_name            = aws_db_subnet_group.main.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.main.name
  vpc_security_group_ids          = [aws_security_group.aurora.id]

  # Encryption
  storage_encrypted = true
  kms_key_id        = var.kms_key_id

  # Backup
  backup_retention_period    = 7
  preferred_backup_window    = "03:00-04:00"

  # Maintenance
  preferred_maintenance_window = "sun:04:00-sun:05:00"

  # Deletion protection
  deletion_protection = false # Set true for production
  skip_final_snapshot = true  # Set false for production

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = {
    Name        = "xelta-${var.environment}-aurora-${var.region}"
    Environment = var.environment
  }
}

# Aurora Cluster Instances
resource "aws_rds_cluster_instance" "main" {
  count              = var.instance_count
  identifier         = "xelta-${var.environment}-aurora-${var.region}-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  publicly_accessible = false

  performance_insights_enabled        = true
  performance_insights_kms_key_id = var.kms_key_id

  tags = {
    Name        = "xelta-${var.environment}-aurora-${var.region}-${count.index + 1}"
    Environment = var.environment
  }
}