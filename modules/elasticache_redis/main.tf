# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "main" {
  name       = "xelta-${var.environment}-redis-subnet-${var.region}"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "xelta-${var.environment}-redis-subnet-${var.region}"
    Environment = var.environment
  }
}

# Security Group for Redis
resource "aws_security_group" "redis" {
  name        = "xelta-${var.environment}-redis-sg-${var.region}"
  description = "Security group for ElastiCache Redis"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
    description     = "Allow Redis access from EKS nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "xelta-${var.environment}-redis-sg-${var.region}"
    Environment = var.environment
  }
}

# Parameter Group
resource "aws_elasticache_parameter_group" "main" {
  name   = "xelta-${var.environment}-redis-params-${var.region}"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  tags = {
    Name        = "xelta-${var.environment}-redis-params-${var.region}"
    Environment = var.environment
  }
}

# ElastiCache Replication Group (Redis)
# Using cluster mode disabled for simplicity; enable cluster mode for production scale
resource "aws_elasticache_replication_group" "main" {
  replication_group_id          = "xelta-${var.environment}-redis-${var.region}"
  replication_group_description = "Redis cluster for xelta ${var.environment} in ${var.region}"

  engine               = "redis"
  engine_version       = "7.0"
  node_type            = var.node_type
  num_cache_clusters   = var.num_cache_nodes
  parameter_group_name = aws_elasticache_parameter_group.main.name

  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.redis.id]

  # Encryption
  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_id
  transit_encryption_enabled = true
  auth_token_enabled         = false # Enable for production with strong token

  # Automatic failover (requires >= 2 nodes)
  automatic_failover_enabled = var.num_cache_nodes > 1 ? true : false
  multi_az_enabled           = var.num_cache_nodes > 1 ? true : false

  # Backup configuration
  snapshot_retention_limit = 7
  snapshot_window          = "03:00-05:00"
  maintenance_window       = "sun:05:00-sun:07:00"

  # Auto minor version upgrade
  auto_minor_version_upgrade = true

  tags = {
    Name        = "xelta-${var.environment}-redis-${var.region}"
    Environment = var.environment
  }
}