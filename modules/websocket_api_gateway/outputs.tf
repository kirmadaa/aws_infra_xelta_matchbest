# modules/websocket_api_gateway/outputs.tf

output "api_endpoint" {
  description = "The endpoint URL for the WebSocket API"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "api_id" {
  description = "The ID of the WebSocket API"
  value       = aws_apigatewayv2_api.main.id
}

output "api_execution_arn" {
  description = "The execution ARN of the WebSocket API"
  value       = aws_apigatewayv2_api.main.execution_arn
}

output "stage_name" {
  description = "The name of the API Gateway stage"
  value       = aws_apigatewayv2_stage.main.name
}