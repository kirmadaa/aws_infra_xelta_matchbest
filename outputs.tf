output "cdn_domain_name" {
  description = "The domain name of the CloudFront distribution."
  value       = module.cdn.cdn_domain_name
}

output "regional_endpoints" {
  description = "A map of the regional Application Load Balancer DNS names."
  value       = { for k, v in module.regional_stack : k => v.frontend_alb_dns_name }
}
