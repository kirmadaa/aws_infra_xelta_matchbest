output "frontend_service_arn" {
  description = "ARN of the frontend ECS service"
  value       = aws_ecs_service.frontend.id
}

output "backend_service_arn" {
  description = "ARN of the backend ECS service"
  value       = aws_ecs_service.backend.id
}

output "frontend_nlb_listener_arn" {
  description = "ARN of the NLB listener for the frontend"
  value       = aws_lb_listener.frontend.arn
}

output "backend_nlb_listener_arn" {
  description = "ARN of the NLB listener for the backend"
  value       = aws_lb_listener.backend.arn
}

output "nlb_arn" {
  description = "ARN of the NLB"
  value       = aws_lb.nlb.arn
}

output "service_security_group_id" {
  description = "ID of the security group for the ECS service"
  value       = aws_security_group.ecs_service.id
}
