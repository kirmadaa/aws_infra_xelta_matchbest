output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "ecs_cluster_id" {
  value = aws_ecs_cluster.main.id
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_task_execution_role_arn" {
  value = aws_iam_role.ecs_task_execution.arn
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

output "backend_nlb_arn" {
  value = aws_lb.backend_nlb.arn
}

output "backend_nlb_dns_name" {
  value = aws_lb.backend_nlb.dns_name
}

output "backend_nlb_listener_arn" {
  value = aws_lb_listener.backend_tcp.arn
}

output "alb_security_group_id" {
  value = aws_security_group.alb_sg.id
}

output "nlb_security_group_id" {
  value = aws_security_group.nlb_sg.id
}
