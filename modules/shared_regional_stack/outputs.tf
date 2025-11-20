output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}


output "frontend_alb_arn" {
  value = aws_lb.frontend_alb.arn
}

output "frontend_alb_dns_name" {
  value = aws_lb.frontend_alb.dns_name
}

output "frontend_alb_listener_arn" {
  value = aws_lb_listener.frontend_http.arn
}

output "alb_security_group_id" {
  value = aws_security_group.alb_sg.id
}
