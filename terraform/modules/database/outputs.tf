output "aurora_cluster_endpoint" { value = aws_rds_cluster.aurora.endpoint }
output "docdb_cluster_endpoint" { value = aws_docdb_cluster.docdb.endpoint }
output "redis_primary_endpoint" { value = aws_elasticache_cluster.redis.cache_nodes[0].address }
output "db_password_secret_arn" { value = aws_secretsmanager_secret.db_password.arn }