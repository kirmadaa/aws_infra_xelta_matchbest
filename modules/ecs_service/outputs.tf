output "service_arn" {
  description = "ARN of the ECS service"
  value       = aws_ecs_service.main.id
}

output "service_security_group_id" {
  description = "ID of the security group for the ECS service"
  value       = aws_security_group.ecs_service.id
}

output "nlb_listener_arn" {
  description = "ARN of the NLB listener"
  value       = aws_lb_listener.main.arn
}

output "nlb_arn" {
  description = "ARN of the NLB"
  value       = aws_lb.main.arn
}
