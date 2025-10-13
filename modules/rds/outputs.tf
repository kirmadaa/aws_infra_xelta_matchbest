output "primary_endpoint" {
  description = "The endpoint of the primary RDS instance"
  value       = aws_db_instance.main[0].endpoint
}

output "read_replica_endpoints" {
  description = "A list of endpoints for the read replicas"
  value       = aws_db_instance.read_replica.*.endpoint
}
