# Create primary RDS instance only in the primary region
resource "aws_db_instance" "main" {
  count = var.region == var.primary_region ? 1 : 0

  identifier             = "xelta-${var.environment}-primary"
  allocated_storage      = var.allocated_storage
  engine                 = "mysql"
  engine_version         = "8.0.28"
  instance_class         = var.instance_class
  db_name                = "xelta"
  username               = var.db_username
  password               = var.db_password
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  skip_final_snapshot    = true

  performance_insights_enabled = true
  monitoring_interval         = 60
  monitoring_role_arn        = aws_iam_role.rds_monitoring.arn
}

# Read replicas for zero-latency reads
resource "aws_db_instance" "read_replica" {
  count = var.region != var.primary_region ? var.num_read_replicas : 0

  identifier                = "xelta-${var.environment}-${var.region}-replica-${count.index}"
  replicate_source_db       = "arn:aws:rds:${var.primary_region}:${data.aws_caller_identity.current.account_id}:db:xelta-${var.environment}-primary"
  instance_class            = var.instance_class
  vpc_security_group_ids    = [aws_security_group.rds.id]
  skip_final_snapshot       = true

  performance_insights_enabled = true
  monitoring_interval         = 60
  monitoring_role_arn        = aws_iam_role.rds_monitoring.arn
}

resource "aws_db_subnet_group" "main" {
  name       = "xelta-${var.environment}-${var.region}-rds"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "rds" {
  name        = "xelta-${var.environment}-${var.region}-rds"
  description = "Allow traffic to RDS from within the VPC"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "rds_monitoring" {
  name = "xelta-${var.environment}-${var.region}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

data "aws_caller_identity" "current" {}
data "aws_vpc" "main" {
  id = var.vpc_id
}
