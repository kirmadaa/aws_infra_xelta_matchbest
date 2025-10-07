data "aws_availability_zones" "available" {
  state = "available"
}

# --- Shared DB Subnet Group ---
resource "aws_db_subnet_group" "default" {
  name       = "${var.project_name}-dbs"
  subnet_ids = var.database_subnet_ids
  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
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
  tags = { Name = "${var.project_name}-aurora-sg" }
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
  tags = { Name = "${var.project_name}-docdb-sg" }
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
  tags = { Name = "${var.project_name}-redis-sg" }
}

# --- Password Management ---
resource "random_password" "db_master_password" {
  length           = 16
  special          = true
  override_special = "!#$%&()*+,-./:;<=>?@[]^_`{|}~"
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project_name}/db/masterpassword"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_master_password.result
}

# --- Redis Auth Token ---
resource "random_password" "redis_auth_token" {
  length  = 32
  special = false # Redis auth tokens are typically alphanumeric
}

resource "aws_secretsmanager_secret" "redis_auth_token" {
  name                    = "${var.project_name}/redis/authtoken"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0
}

resource "aws_secretsmanager_secret_version" "redis_auth_token" {
  secret_id     = aws_secretsmanager_secret.redis_auth_token.id
  secret_string = random_password.redis_auth_token.result
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
  storage_encrypted       = true
}

resource "aws_rds_cluster_instance" "aurora" {
  count              = var.environment == "prod" ? 2 : 1 # Multi-AZ for Prod
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = var.aurora_instance_class
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version
}



# --- ElastiCache (Redis) ---
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project_name}-redis"
  subnet_ids = var.database_subnet_ids
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "${var.project_name}-redis"
  description                = "Redis replication group for ${var.project_name}"
  node_type                  = var.redis_node_type
  num_cache_clusters         = var.redis_node_count
  port                       = 6379
  subnet_group_name          = aws_elasticache_subnet_group.redis.name
  security_group_ids         = [aws_security_group.redis.id]
  automatic_failover_enabled = var.redis_node_count > 1

  # Production readiness: enable at-rest and in-transit encryption
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.redis_auth_token.result
}
