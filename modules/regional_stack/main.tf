# REGIONAL RESOURCES (VPC, ECS, API GW, LAMBDA, etc.)

# NETWORKING
module "vpc" {
  source = "../vpc"

  environment        = var.environment
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  single_nat_gateway = var.single_nat_gateway
}

# ECS
module "ecs_service" {
  source = "../ecs_service"

  environment            = var.environment
  region                 = var.region
  vpc_id                 = module.vpc.vpc_id
  vpc_cidr               = var.vpc_cidr
  private_subnet_ids     = module.vpc.private_subnet_ids
  public_subnet_ids      = module.vpc.public_subnet_ids
  frontend_image         = var.frontend_image
  backend_image          = var.backend_image
  http_api_vpclink_sg_id = aws_security_group.http_api_vpclink_sg.id
  task_cpu               = var.ecs_task_cpu
  task_memory            = var.ecs_task_memory

  # OBSERVABILITY
  enable_container_insights   = var.enable_container_insights
  cloudwatch_log_retention_days = var.cloudwatch_log_retention_days
}

# REDIS
module "redis" {
  count  = var.enable_redis ? 1 : 0
  source = "../elasticache_redis"

  environment                = var.environment
  region                     = var.region
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  node_type                  = var.redis_node_type
  num_cache_nodes            = var.redis_num_cache_nodes
  allowed_security_group_ids = [module.ecs_service.service_security_group_id]
}

# SERVERLESS BACKEND (SQS, S3, DYNAMODB)
resource "aws_sqs_queue" "jobs" {
  name = "xelta-${var.environment}-jobs-${var.region}"
}

resource "aws_s3_bucket" "results" {
  bucket = "xelta-${var.environment}-results-${var.region}"
}

resource "aws_dynamodb_table" "jobs" {
  name         = "xelta-${var.environment}-jobs-${var.region}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "jobId"

  attribute {
    name = "jobId"
    type = "S"
  }
}

# LAMBDA
resource "aws_iam_role" "lambda_exec" {
  name = "xelta-${var.environment}-lambda-exec-${var.region}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_xray" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_insights" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLambdaInsightsExecutionRolePolicy"
}

resource "aws_iam_policy" "lambda_policy" {
  name = "xelta-${var.environment}-lambda-policy-${var.region}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Effect   = "Allow"
        Resource = aws_sqs_queue.jobs.arn
      },
      {
        Action   = ["dynamodb:PutItem"]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.jobs.arn
      },
      {
        Action   = ["s3:PutObject"]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.results.arn}/*"
      },
      {
        Action   = ["execute-api:ManageConnections"]
        Effect   = "Allow"
        Resource = "arn:aws:execute-api:${var.region}:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_lambda_function" "connect_handler" {
  function_name    = "xelta-${var.environment}-connect-handler-${var.region}"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "nodejs16.x"
  memory_size      = var.lambda_memory_size
  filename         = "${path.module}/../../lambda/connect.zip"
  source_code_hash = filebase64sha256("${path.module}/../../lambda/connect.zip")
  tracing_config {
    mode = "Active"
  }
  layers = [
    "arn:aws:lambda:${var.region}:580247275435:layer:LambdaInsightsExtension:60"
  ]
  logging_config {
    log_group = aws_cloudwatch_log_group.connect_handler.name
  }
}

resource "aws_lambda_function" "start_job_handler" {
  function_name    = "xelta-${var.environment}-start-job-handler-${var.region}"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "nodejs16.x"
  memory_size      = var.lambda_memory_size
  filename         = "${path.module}/../../lambda/start_job.zip"
  source_code_hash = filebase64sha256("${path.module}/../../lambda/start_job.zip")
  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.jobs.name
      SQS_QUEUE_URL  = aws_sqs_queue.jobs.id
    }
  }
  tracing_config {
    mode = "Active"
  }
  layers = [
    "arn:aws:lambda:${var.region}:580247275435:layer:LambdaInsightsExtension:60"
  ]
  logging_config {
    log_group = aws_cloudwatch_log_group.start_job_handler.name
  }
}

resource "aws_lambda_function" "worker" {
  function_name    = "xelta-${var.environment}-worker-${var.region}"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "nodejs16.x"
  memory_size      = var.lambda_memory_size
  filename         = "${path.module}/../../lambda/worker.zip"
  source_code_hash = filebase64sha256("${path.module}/../../lambda/worker.zip")
  vpc_config {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [module.ecs_service.worker_lambda_sg_id]
  }
  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.jobs.name
      S3_BUCKET      = aws_s3_bucket.results.id
    }
  }
  tracing_config {
    mode = "Active"
  }
  layers = [
    "arn:aws:lambda:${var.region}:580247275435:layer:LambdaInsightsExtension:60"
  ]
  logging_config {
    log_group = aws_cloudwatch_log_group.worker.name
  }
}

resource "aws_lambda_event_source_mapping" "worker_trigger" {
  event_source_arn = aws_sqs_queue.jobs.arn
  function_name    = aws_lambda_function.worker.arn
}

# API GATEWAY
resource "aws_security_group" "http_api_vpclink_sg" {
  name        = "xelta-http-api-${var.environment}-${var.region}-vpclink-sg"
  description = "Allow traffic from HTTP API Gateway VPC Link"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_apigatewayv2_api" "http_api" {
  name          = "xelta-http-api-${var.environment}-${var.region}"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins     = var.api_gateway_cors_origins
    allow_methods     = var.api_gateway_cors_methods
    allow_headers     = var.api_gateway_cors_headers
    allow_credentials = true
  }
}

resource "aws_apigatewayv2_vpc_link" "http_api" {
  name               = "xelta-http-api-${var.environment}-${var.region}-vpclink"
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [aws_security_group.http_api_vpclink_sg.id]
}

resource "aws_apigatewayv2_integration" "http_api" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = module.ecs_service.backend_nlb_listener_arn
  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.http_api.id
}

resource "aws_apigatewayv2_route" "http_api" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.http_api.id}"
}

resource "aws_apigatewayv2_stage" "http_api" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

module "websocket_api_gateway" {
  source = "../websocket_api_gateway"

  environment           = var.environment
  region                = var.region
  vpc_id                = module.vpc.vpc_id
  connect_lambda_arn    = aws_lambda_function.connect_handler.arn
  default_lambda_arn    = aws_lambda_function.start_job_handler.arn
  disconnect_lambda_arn = aws_lambda_function.connect_handler.arn
}

# OBSERVABILITY
resource "aws_cloudwatch_log_group" "connect_handler" {
  name              = "/aws/lambda/xelta-${var.environment}-connect-handler-${var.region}"
  retention_in_days = var.cloudwatch_log_retention_days
}

resource "aws_cloudwatch_log_group" "start_job_handler" {
  name              = "/aws/lambda/xelta-${var.environment}-start-job-handler-${var.region}"
  retention_in_days = var.cloudwatch_log_retention_days
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/aws/lambda/xelta-${var.environment}-worker-${var.region}"
  retention_in_days = var.cloudwatch_log_retention_days
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "xelta-${var.environment}-${var.region}"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", module.ecs_service.ecs_cluster_name, { "label" = "ECS CPU Utilization" }],
            [".", "MemoryUtilization", ".", ".", { "label" = "ECS Memory Utilization" }]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "ECS Cluster Metrics"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 7
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.connect_handler.function_name, { "label" = "Connect Handler Errors" }],
            [".", ".", "FunctionName", aws_lambda_function.start_job_handler.function_name, { "label" = "Start Job Handler Errors" }],
            [".", ".", "FunctionName", aws_lambda_function.worker.function_name, { "label" = "Worker Errors" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "Lambda Errors"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 14
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", module.ecs_service.frontend_alb_arn_suffix, { "label" = "ALB 5xx Errors" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "ALB Errors"
        }
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  alarm_name          = "xelta-${var.environment}-${var.region}-ecs-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = var.alarm_period_seconds
  statistic           = "Average"
  threshold           = var.alarm_threshold
  alarm_description   = "High CPU utilization on the ECS cluster"
  alarm_actions       = [var.alarm_sns_topic_arn]
  dimensions = {
    ClusterName = module.ecs_service.ecs_cluster_name
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "xelta-${var.environment}-${var.region}-lambda-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = var.alarm_period_seconds
  statistic           = "Sum"
  threshold           = var.alarm_threshold
  alarm_description   = "High number of errors on Lambda functions"
  alarm_actions       = [var.alarm_sns_topic_arn]
  dimensions = {
    FunctionName = aws_lambda_function.connect_handler.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "xelta-${var.environment}-${var.region}-alb-5xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = var.alarm_period_seconds
  statistic           = "Sum"
  threshold           = var.alarm_threshold
  alarm_description   = "High number of 5xx errors on the ALB"
  alarm_actions       = [var.alarm_sns_topic_arn]
  dimensions = {
    LoadBalancer = module.ecs_service.frontend_alb_arn_suffix
  }
}
