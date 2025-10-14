# modules/ecs_service/outputs.tf

output "frontend_nlb_listener_arn" {
  description = "ARN of the NLB listener for the frontend"
  value       = aws_lb_listener.frontend.arn
}

output "backend_nlb_listener_arn" {
  description = "ARN of the NLB listener for the backend"
  value       = aws_lb_listener.backend.arn
}

output "service_security_group_id" {
  description = "ID of the security group for the ECS service"
  value       = aws_security_group.ecs_service.id
}

output "backend_service_name" {
  description = "Name of the backend ECS service"
  value       = aws_ecs_service.backend.name
}

output "frontend_service_name" {
  description = "Name of the frontend ECS service"
  value       = aws_ecs_service.frontend.name
}

output "nlb_arn_suffix" {
  description = "ARN suffix of the Network Load Balancer"
  value       = aws_lb.nlb.arn_suffix
}
