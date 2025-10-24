# modules/websocket_api_gateway/main.tf

# API Gateway v2 (WebSocket API)
resource "aws_apigatewayv2_api" "main" {
  name                         = "xelta-websocket-${var.environment}-${var.region}"
  protocol_type                = "WEBSOCKET"
  route_selection_expression = "$request.body.action"

  tags = {
    Name        = "xelta-websocket-${var.environment}-${var.region}"
    Environment = var.environment
  }
}

# IAM Role for API Gateway to write to CloudWatch Logs
resource "aws_iam_role" "api_gateway_logging" {
  name = "xelta-websocket-${var.environment}-${var.region}-logging-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })
}

# Attach the AWS managed policy for API Gateway CloudWatch logging
resource "aws_iam_role_policy_attachment" "api_gateway_logging" {
  role       = aws_iam_role.api_gateway_logging.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_logging.arn

  depends_on = [aws_iam_role_policy_attachment.api_gateway_logging]
}

# API Gateway Integrations for Lambda functions
resource "aws_apigatewayv2_integration" "connect" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri  = var.connect_lambda_arn
}

resource "aws_apigatewayv2_integration" "default" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri  = var.default_lambda_arn
}

resource "aws_apigatewayv2_integration" "disconnect" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri  = var.disconnect_lambda_arn
}

# WebSocket Routes
resource "aws_apigatewayv2_route" "connect" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "$connect"
  target    = "integrations/${aws_apigatewayv2_integration.connect.id}"
}

resource "aws_apigatewayv2_route" "disconnect" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.disconnect.id}"
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.default.id}"
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 500
    throttling_rate_limit  = 1000
  }

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

  depends_on = [aws_api_gateway_account.main]
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
