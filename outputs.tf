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

# WebSocket API Endpoints
output "websocket_api_endpoint_us_east_1" {
  description = "WebSocket API endpoint in us-east-1"
  value       = var.enable_websocket_api ? module.websocket_api_gateway_us_east_1[0].api_endpoint : "WebSocket API disabled"
}

output "websocket_api_endpoint_eu_central_1" {
  description = "WebSocket API endpoint in eu-central-1"
  value       = var.enable_websocket_api ? module.websocket_api_gateway_eu_central_1[0].api_endpoint : "WebSocket API disabled"
}

output "websocket_api_endpoint_ap_south_1" {
  description = "WebSocket API endpoint in ap-south-1"
  value       = var.enable_websocket_api ? module.websocket_api_gateway_ap_south_1[0].api_endpoint : "WebSocket API disabled"
}
