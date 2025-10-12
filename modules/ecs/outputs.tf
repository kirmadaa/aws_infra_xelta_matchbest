output "service_security_group_id" {
  description = "The security group ID for the ECS service"
  value       = aws_security_group.service_sg.id
}
