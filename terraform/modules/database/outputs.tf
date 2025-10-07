output "aurora_cluster_endpoint" {
  description = "The endpoint for the Aurora PostgreSQL cluster."
  value       = aws_rds_cluster.aurora.endpoint
}

output "docdb_cluster_endpoint" {
  description = "The endpoint for the DocumentDB cluster."
  value       = aws_docdb_cluster.docdb.endpoint
}

output "redis_primary_endpoint" {
  description = "The primary endpoint for the ElastiCache Redis replication group."
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "db_password_secret_arn" {
  description = "The ARN of the secret containing the database master password."
  value       = aws_secretsmanager_secret.db_password.arn
}