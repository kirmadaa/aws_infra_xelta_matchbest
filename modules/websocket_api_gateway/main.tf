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

# VPC Link for API Gateway to connect to private resources
resource "aws_api_gateway_vpc_link" "main" {
  name        = "xelta-websocket-${var.environment}-${var.region}-v1"
  target_arns = [var.nlb_arn]

  tags = {
    Name        = "xelta-websocket-${var.environment}-vpclink-${var.region}"
    Environment = var.environment
  }
}

# API Gateway Integration for all routes
resource "aws_apigatewayv2_integration" "main" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = var.nlb_listener_arn
  connection_type    = "VPC_LINK"
  connection_id      = aws_api_gateway_vpc_link.main.id
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

resource "aws_iam_role_policy" "api_gateway_logging" {
  name = "xelta-websocket-${var.environment}-${var.region}-logging-policy"
  role = aws_iam_role.api_gateway_logging.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents",
        "logs:GetLogEvents",
        "logs:FilterLogEvents"
      ]
      Effect   = "Allow"
      Resource = "${aws_cloudwatch_log_group.api_gateway.arn}:*"
    }]
  })
}

resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_logging.arn
}

# WebSocket Routes
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

resource "aws_apigatewayv2_route" "custom" {
  for_each  = toset(var.custom_routes)
  api_id    = aws_apigatewayv2_api.main.id
  route_key = each.key
  target    = "integrations/${aws_apigatewayv2_integration.main.id}"
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