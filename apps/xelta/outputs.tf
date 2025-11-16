output "frontend_alb_dns_name" {
  description = "DNS name of the frontend ALB"
  value       = var.enable_xelta ? aws_lb.frontend_alb[0].dns_name : null
}
