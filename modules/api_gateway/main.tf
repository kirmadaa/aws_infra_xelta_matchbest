# API Gateway v2 (HTTP API)
resource "aws_apigatewayv2_api" "main" {
  name          = "xelta-${var.environment}-${var.region}"
  protocol_type = "HTTP"
}

# VPC Link for API Gateway to connect to private resources
resource "aws_apigatewayv2_vpc_link" "main" {
  name               = "xelta-${var.environment}-${var.region}-v2"
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [var.ecs_service_security_group_id]
}

# API Gateway Integration
resource "aws_apigatewayv2_integration" "main" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = var.nlb_listener_arn
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
}

# API Gateway Route
resource "aws_apigatewayv2_route" "main" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.main.id}"
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
}
