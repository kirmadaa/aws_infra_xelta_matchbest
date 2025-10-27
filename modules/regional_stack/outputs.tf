output "frontend_alb_dns_name" {
  description = "The DNS name of the frontend Application Load Balancer"
  value       = module.ecs_service.frontend_alb_dns_name
}
