# modules/api_gateway/main.tf

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

# API Gateway Integration for Frontend
resource "aws_apigatewayv2_integration" "frontend" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = var.frontend_nlb_listener_arn
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id

  timeout_milliseconds = 30000
}

# API Gateway Integration for Backend
resource "aws_apigatewayv2_integration" "backend" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = var.backend_nlb_listener_arn
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
  
  timeout_milliseconds = 30000
}

# IAM Role for API Gateway to SQS
resource "aws_iam_role" "api_gateway_sqs" {
  count = var.enable_sqs_integration ? 1 : 0
  name  = "xelta-${var.environment}-${var.region}-api-gateway-sqs-role"

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

resource "aws_iam_role_policy" "api_gateway_sqs" {
  count = var.enable_sqs_integration ? 1 : 0
  name  = "xelta-${var.environment}-${var.region}-api-gateway-sqs-policy"
  role  = aws_iam_role.api_gateway_sqs[0].id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action   = "sqs:SendMessage"
        Effect   = "Allow"
        Resource = var.sqs_queue_arn
      }
    ]
  })
}

# API Gateway Integration for SQS
resource "aws_apigatewayv2_integration" "sqs" {
  count              = var.enable_sqs_integration ? 1 : 0
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "AWS_PROXY"
  integration_subtype = "SQS-SendMessage"
  credentials_arn    = aws_iam_role.api_gateway_sqs[0].arn

  request_parameters = {
    "QueueUrl"    = var.sqs_queue_url
    "MessageBody" = "$request.body"
  }
}

# API Gateway Route for Frontend (Default)
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.frontend.id}"
}

# API Gateway Route for Backend API
resource "aws_apigatewayv2_route" "backend" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /api/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.backend.id}"
}

# API Gateway Route for SQS
resource "aws_apigatewayv2_route" "sqs" {
  count      = var.enable_sqs_integration ? 1 : 0
  api_id     = aws_apigatewayv2_api.main.id
  route_key  = "POST /jobs"
  target     = "integrations/${aws_apigatewayv2_integration.sqs[0].id}"
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
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/xelta-${var.environment}-${var.region}"
  retention_in_days = 7

  tags = {
    Name        = "xelta-${var.environment}-apigw-logs-${var.region}"
    Environment = var.environment
  }
}

# Add a custom domain for the API Gateway
resource "aws_apigatewayv2_domain_name" "main" {
  domain_name = "api-${var.region}.${var.domain_name}"

  domain_name_configuration {
    certificate_arn = var.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  domain_name = aws_apigatewayv2_domain_name.main.id
  stage       = aws_apigatewayv2_stage.main.id
}
