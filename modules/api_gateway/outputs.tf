output "api_endpoint" {
  description = "The endpoint of the API Gateway"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "api_gateway_domain_name" {
    description = "The regional custom domain name of the API Gateway"
    value = aws_apigatewayv2_domain_name.main.domain_name_configuration[0].target_domain_name
}
