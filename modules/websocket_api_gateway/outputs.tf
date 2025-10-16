output "api_id" {
  description = "The ID of the WebSocket API Gateway"
  value       = aws_apigatewayv2_api.main.id
}

output "api_endpoint" {
  description = "The endpoint of the WebSocket API Gateway"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "api_arn" {
  description = "The ARN of the WebSocket API Gateway"
  value       = aws_apigatewayv2_api.main.arn
}