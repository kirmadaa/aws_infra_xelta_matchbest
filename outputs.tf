# Global Outputs
output "cdn_domain_name" {
  description = "The domain name of the CloudFront distribution"
  value       = module.cdn.cdn_dns_name
}

output "route53_zone_id" {
  description = "Route53 hosted zone ID for xelta.ai"
  value       = data.aws_route53_zone.main.zone_id
}

output "route53_domain" {
  description = "Domain name configured in Route53"
  value       = var.domain_name
}

# Regional Redis Outputs
output "redis_endpoint_us_east_1" {
  description = "Redis endpoint in us-east-1"
  value       = var.enable_redis ? module.redis_us_east_1[0].redis_endpoint : "Redis disabled"
}

output "redis_endpoint_eu_central_1" {
  description = "Redis endpoint in eu-central-1"
  value       = var.enable_redis ? module.redis_eu_central_1[0].redis_endpoint : "Redis disabled"
}

output "redis_endpoint_ap_south_1" {
  description = "Redis endpoint in ap-south-1"
  value       = var.enable_redis ? module.redis_ap_south_1[0].redis_endpoint : "Redis disabled"
}

# Regional SQS Outputs
output "sqs_queue_url_us_east_1" {
  description = "SQS Queue URL in us-east-1"
  value       = module.sqs_us_east_1.jobs_queue_url
}

output "sqs_queue_url_eu_central_1" {
  description = "SQS Queue URL in eu-central-1"
  value       = module.sqs_eu_central_1.jobs_queue_url
}

output "sqs_queue_url_ap_south_1" {
  description = "SQS Queue URL in ap-south-1"
  value       = module.sqs_ap_south_1.jobs_queue_url
}

# Regional API Gateway Outputs
output "api_gateway_endpoint_us_east_1" {
  description = "API Gateway endpoint in us-east-1"
  value       = module.api_gateway_us_east_1.api_endpoint
}

output "api_gateway_endpoint_eu_central_1" {
  description = "API Gateway endpoint in eu-central-1"
  value       = module.api_gateway_eu_central_1.api_endpoint
}

output "api_gateway_endpoint_ap_south_1" {
  description = "API Gateway endpoint in ap-south-1"
  value       = module.api_gateway_ap_south_1.api_endpoint
}