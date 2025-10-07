data "aws_availability_zones" "available" {
  state = "available"
}

# --- Shared DB Subnet Group ---
resource "aws_db_subnet_group" "default" {
  name       = "${var.project_name}-dbs"
  subnet_ids = var.database_subnet_ids
}

# --- Security Groups ---
resource "aws_security_group" "aurora" {
  name   = "${var.project_name}-aurora-sg"
  vpc_id = var.vpc_id
  ingress {
    protocol        = "tcp"
    from_port       = 5432
    to_port         = 5432
    security_groups = [var.eks_node_security_group_id]
  }
}

resource "aws_security_group" "docdb" {
  name   = "${var.project_name}-docdb-sg"
  vpc_id = var.vpc_id
  ingress {
    protocol        = "tcp"
    from_port       = 27017
    to_port         = 27017
    security_groups = [var.eks_node_security_group_id]
  }
}

resource "aws_security_group" "redis" {
  name   = "${var.project_name}-redis-sg"
  vpc_id = var.vpc_id
  ingress {
    protocol        = "tcp"
    from_port       = 6379
    to_port         = 6379
    security_groups = [var.eks_node_security_group_id]
  }
}

# --- Password Management ---
resource "random_password" "db_master_password" {
  length  = 16
  special = true
}

resource "aws_secretsmanager_secret" "db_password" {
  name = "${var.project_name}/db/masterpassword"
  recovery_window_in_days = 0 # Set to 30 for prod
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_master_password.result
}

# --- Aurora (PostgreSQL) ---
resource "aws_rds_cluster" "aurora" {
  cluster_identifier      = "${var.project_name}-aurora"
  engine                  = "aurora-postgresql"
  engine_mode             = "provisioned"
  engine_version          = "14.7"
  database_name           = "appdb"
  master_username         = "masteruser"
  master_password         = random_password.db_master_password.result
  db_subnet_group_name    = aws_db_subnet_group.default.name
  vpc_security_group_ids  = [aws_security_group.aurora.id]
  skip_final_snapshot     = var.db_skip_final_snapshot
}

resource "aws_rds_cluster_instance" "aurora" {
  count              = 2 # Multi-AZ
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = var.aurora_instance_class
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version
}

# --- DocumentDB ---
resource "aws_docdb_cluster" "docdb" {
  cluster_identifier      = "${var.project_name}-docdb"
  engine                  = "docdb"
  master_username         = "masteruser"
  master_password         = random_password.db_master_password.result
  db_subnet_group_name    = aws_db_subnet_group.default.name
  vpc_security_group_ids  = [aws_security_group.docdb.id]
  skip_final_snapshot     = var.db_skip_final_snapshot
}

resource "aws_docdb_cluster_instance" "docdb" {
  count              = 2 # Multi-AZ
  cluster_identifier = aws_docdb_cluster.docdb.id
  instance_class     = var.docdb_instance_class
}

# --- ElastiCache (Redis) ---
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project_name}-redis"
  subnet_ids = var.database_subnet_ids
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.project_name}-redis"
  engine               = "redis"
  node_type            = var.redis_node_type
  num_cache_nodes      = var.redis_node_count
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.redis.id]
}