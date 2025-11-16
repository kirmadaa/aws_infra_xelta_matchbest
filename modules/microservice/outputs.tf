output "service_arn" {
  description = "ARN of the ECS service"
  value       = aws_ecs_service.main.id
}
