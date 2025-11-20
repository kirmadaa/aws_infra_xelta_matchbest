output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = module.route53_acm.certificate_arn
}

output "http_api_endpoint" {
  description = "HTTP API Gateway Endpoint"
  value       = aws_apigatewayv2_api.http_api.api_endpoint
}

output "websocket_api_endpoint" {
  description = "WebSocket API Gateway Endpoint"
  value       = var.enable_websocket_api ? module.websocket_api_gateway[0].api_endpoint : ""
}
