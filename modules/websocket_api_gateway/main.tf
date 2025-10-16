# API Gateway v2 (WebSocket API)
resource "aws_apigatewayv2_api" "main" {
  name                       = "xelta-websocket-${var.environment}-${var.region}"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}

# VPC Link for API Gateway to connect to private resources
resource "aws_apigatewayv2_vpc_link" "main" {
  name               = "xelta-websocket-${var.environment}-${var.region}-v2"
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [var.ecs_service_security_group_id]
}

# IAM Role for API Gateway to access the NLB
resource "aws_iam_role" "apigw_integration" {
  name = "xelta-websocket-${var.environment}-${var.region}-apigw-integration-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "apigw_integration" {
  name = "xelta-websocket-${var.environment}-${var.region}-apigw-integration-policy"
  role = aws_iam_role.apigw_integration.id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action   = "elasticloadbalancing:*"
        Effect   = "Allow"
        Resource = var.nlb_listener_arn
      }
    ]
  })
}

# API Gateway Integration
resource "aws_apigatewayv2_integration" "main" {
  api_id                  = aws_apigatewayv2_api.main.id
  integration_type        = "AWS_PROXY"
  integration_subtype     = "HTTPProxy"
  integration_uri         = var.nlb_listener_arn
  connection_type         = "VPC_LINK"
  connection_id           = aws_apigatewayv2_vpc_link.main.id
  credentials_arn         = aws_iam_role.apigw_integration.arn
  request_parameters = {
    "integration.request.header.X-Amz-Target" = "none" # Placeholder, can be customized
  }
  timeout_milliseconds    = (var.connection_timeout_minutes * 60 * 1000) - 1000 # Set timeout just under the limit
}

# API Gateway Routes
resource "aws_apigatewayv2_route" "connect" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "$connect"
  target    = "integrations/${aws_apigatewayv2_integration.main.id}"
}

resource "aws_apigatewayv2_route" "disconnect" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.main.id}"
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.main.id}"
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      connectionId   = "$context.connectionId"
    })
  }
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/xelta-websocket-${var.environment}-${var.region}"
  retention_in_days = 30

  tags = {
    Name        = "xelta-websocket-${var.environment}-apigw-logs-${var.region}"
    Environment = var.environment
  }
}