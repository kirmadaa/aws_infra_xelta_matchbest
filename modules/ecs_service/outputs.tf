# --- NEW: Outputs for Frontend ALB ---
output "frontend_alb_dns_name" {
  description = "DNS name of the frontend Application Load Balancer"
  value       = aws_lb.frontend_alb.dns_name
}

output "frontend_alb_listener_arn" {
  description = "ARN of the ALB listener for the frontend"
  value       = aws_lb_listener.frontend_http.arn
}

# --- Updated: Outputs for Backend NLB ---
output "backend_nlb_listener_arn" {
  description = "ARN of the NLB listener for the backend"
  value       = aws_lb_listener.backend_tcp.arn
}

output "backend_nlb_arn" {
  description = "ARN of the backend NLB"
  value       = aws_lb.backend_nlb.arn
}

# --- Original Outputs ---
output "frontend_service_arn" {
  description = "ARN of the frontend ECS service"
  value       = aws_ecs_service.frontend.id
}

output "backend_service_arn" {
  description = "ARN of the backend ECS service"
  value       = aws_ecs_service.backend.id
}

output "service_security_group_id" {
  description = "ID of the security group for the ECS service"
  value       = aws_security_group.ecs_service.id
}

output "worker_lambda_sg_id" {
  description = "ID of the security group for the worker lambda"
  value       = aws_security_group.worker_lambda_sg.id
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "backend_service_name" {
  description = "Name of the backend ECS service"
  value       = aws_ecs_service.backend.name
}

output "backend_target_group_arn" {
  description = "ARN of the backend target group"
  value       = aws_lb_target_group.backend_tcp.arn
}