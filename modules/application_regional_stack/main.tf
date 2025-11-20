# --- ECS Cluster ---
resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-${var.environment}-${var.region}"
}

# --- IAM Role for ECS Task Execution ---
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.app_name}-${var.environment}-${var.region}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "ecs_exec" {
  name        = "${var.app_name}-${var.environment}-${var.region}-ecs-exec-policy"
  description = "Allow ECS tasks to be accessed via ECS Exec"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_exec" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = aws_iam_policy.ecs_exec.arn
}

# Global secrets (replicated to this region)
module "secrets" {
  source      = "../secrets"
  environment = var.environment
}

# --- DynamoDB ---
resource "aws_dynamodb_table" "jobs" {
  name         = "${var.app_name}-${var.environment}-jobs-${var.region}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "jobId"

  attribute {
    name = "jobId"
    type = "S"
  }
}

# --- SQS ---
resource "aws_sqs_queue" "jobs" {
  name     = "${var.app_name}-${var.environment}-jobs-${var.region}"
}

# --- S3 ---
resource "aws_s3_bucket" "results" {
  bucket   = "${var.app_name}-${var.environment}-results-${var.region}"
}

resource "aws_s3_bucket_lifecycle_configuration" "results" {
  bucket   = aws_s3_bucket.results.id

  rule {
    id     = "intelligent-tiering"
    status = "Enabled"
    filter {} 

    transition {
      days          = 0
      storage_class = "INTELLIGENT_TIERING"
    }
  }
}

# --- IAM Role for Lambdas ---
resource "aws_iam_role" "lambda_exec" {
  name               = "${var.app_name}-${var.environment}-lambda-exec-${var.region}"
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

resource "aws_iam_policy" "lambda_policy" {
  name     = "${var.app_name}-${var.environment}-lambda-policy-${var.region}"
  policy   = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Effect   = "Allow"
        Resource = aws_sqs_queue.jobs.arn
      },
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
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

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# --- ConnectHandler Lambda ---
resource "aws_lambda_function" "connect_handler" {
  function_name    = "${var.app_name}-${var.environment}-connect-handler-${var.region}"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = var.lambda_connect_zip_path
  source_code_hash = filebase64sha256(var.lambda_connect_zip_path)

  lifecycle {
    ignore_changes = all
  }
}

# --- StartJobHandler Lambda ---
resource "aws_lambda_function" "start_job_handler" {
  function_name    = "${var.app_name}-${var.environment}-start-job-handler-${var.region}"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = var.lambda_start_job_zip_path
  source_code_hash = filebase64sha256(var.lambda_start_job_zip_path)

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.jobs.name
      SQS_QUEUE_URL  = aws_sqs_queue.jobs.id
    }
  }

  lifecycle {
    ignore_changes = all
  }
}

# --- Worker Lambda ---
resource "aws_lambda_function" "worker" {
  function_name    = "${var.app_name}-${var.environment}-worker-${var.region}"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = var.lambda_worker_zip_path
  source_code_hash = filebase64sha256(var.lambda_worker_zip_path)

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.worker_lambda_sg.id]
  }

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.jobs.name
      S3_BUCKET      = aws_s3_bucket.results.id
      BACKEND_API_ENDPOINT   = "http://${aws_lb.backend_nlb.dns_name}:8080"
      WEBSOCKET_API_ENDPOINT = var.enable_websocket_api ? module.websocket_api_gateway[0].api_endpoint : ""
    }
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "aws_lambda_event_source_mapping" "worker_trigger" {
  event_source_arn = aws_sqs_queue.jobs.arn
  function_name    = aws_lambda_function.worker.arn
}

# --- ECS Service (App Specific) ---
# We are NOT calling the 'ecs_service' module anymore because it creates the Cluster/ALB.
# Instead, we define the Service/TaskDef here directly, using the shared Cluster/ALB.

# Log Groups
resource "aws_cloudwatch_log_group" "frontend" {
  name = "/aws/ecs/${var.app_name}-${var.environment}-frontend-${var.region}"
  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_log_group" "backend" {
  name = "/aws/ecs/${var.app_name}-${var.environment}-backend-${var.region}"
  tags = { Environment = var.environment }
}

# Security Group for ECS Service
resource "aws_security_group" "ecs_service" {
  name        = "${var.app_name}-${var.environment}-${var.region}-ecs-service"
  description = "Allow traffic ONLY from the LBs"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.nlb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "worker_lambda_sg" {
  name        = "${var.app_name}-${var.environment}-${var.region}-worker-lambda"
  description = "Allow outbound traffic from worker lambda"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Frontend Task Def & Service
resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.app_name}-${var.environment}-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = var.frontend_image
      cpu       = 100
      memory    = 256
      essential = true
      portMappings = [{ containerPort = 3000, hostPort = 3000 }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "frontend" {
  name                   = "${var.app_name}-${var.environment}-frontend"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.frontend.arn
  desired_count          = 2
  enable_execute_command = true
  launch_type            = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.ecs_service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend_http.arn
    container_name   = "frontend"
    container_port   = 3000
  }
}

resource "aws_lb_target_group" "frontend_http" {
  name_prefix = substr("${var.app_name}-fe-", 0, 6)
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    protocol = "HTTP"
    path     = "/"
  }
  lifecycle {
    create_before_destroy = true
  }
}

# Listener Rule to route traffic to this app's target group
# For now, we route everything /* to this app.
# In a real multi-app scenario, we'd use host-header routing (e.g. xelta.example.com)
resource "aws_lb_listener_rule" "frontend_routing" {
  listener_arn = var.frontend_alb_listener_arn
  priority     = var.lb_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_http.arn
  }

  condition {
    path_pattern {
      values = [var.lb_path_pattern]
    }
  }
}


# ==========================================
# Team-Specific Internal NLB
# ==========================================

# Security Group for this team's NLB
resource "aws_security_group" "nlb_sg" {
  name        = "${var.app_name}-${var.environment}-${var.region}-nlb"
  description = "Allow TCP traffic from VPC for team backend"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
    description = "Allow internal traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name        = "${var.app_name}-${var.environment}-nlb-sg"
    Environment = var.environment
  }
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Team-Specific NLB
resource "aws_lb" "backend_nlb" {
  name               = "${var.app_name}-${var.environment}-${var.region}-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.private_subnet_ids

  tags = {
    Name        = "${var.app_name}-${var.environment}-backend-nlb"
    Environment = var.environment
  }
}

# Listener on team's NLB
resource "aws_lb_listener" "backend_tcp" {
  load_balancer_arn = aws_lb.backend_nlb.arn
  port              = 8080
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tcp.arn
  }
}


# Backend Task Definition
resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.app_name}-${var.environment}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = var.backend_image
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [{ containerPort = 5000, hostPort = 5000 }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "backend" {
  name                   = "${var.app_name}-${var.environment}-backend"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.backend.arn
  desired_count          = 2
  enable_execute_command = true
  launch_type            = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.ecs_service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_tcp.arn
    container_name   = "backend"
    container_port   = 5000
  }
}

resource "aws_lb_target_group" "backend_tcp" {
  name_prefix = substr("${var.app_name}-be-", 0, 6)
  port        = 5000
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  lifecycle { create_before_destroy = true }
}

# ... (Redis, Route53, etc. remain similar but using shared VPC)

module "route53_acm" {
  source    = "../route53_acm"

  environment     = var.environment
  region          = var.region
  domain_name     = var.domain_name
  route53_zone_id = var.route53_zone_id

  cdn_dns_name    = var.cdn_dns_name
  cdn_zone_id     = var.cdn_zone_id
}

module "redis" {
  count     = var.enable_redis ? 1 : 0
  source    = "../elasticache_redis"

  environment                = var.environment
  region                     = var.region
  vpc_id                     = var.vpc_id
  private_subnet_ids         = var.private_subnet_ids
  node_type                  = var.redis_node_type
  num_cache_nodes            = var.redis_num_cache_nodes
  allowed_security_group_ids = [aws_security_group.ecs_service.id]
}

module "websocket_api_gateway" {
  count     = var.enable_websocket_api ? 1 : 0
  source    = "../websocket_api_gateway"

  environment           = var.environment
  region                = var.region
  vpc_id                = var.vpc_id
  connect_lambda_arn    = aws_lambda_function.connect_handler.arn
  default_lambda_arn    = aws_lambda_function.start_job_handler.arn
  disconnect_lambda_arn = aws_lambda_function.connect_handler.arn
}

# --- API Gateway Lambda Permissions ---
resource "aws_lambda_permission" "connect_handler" {
  count         = var.enable_websocket_api ? 1 : 0
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.connect_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.websocket_api_gateway[0].api_execution_arn}/*/$connect"
}

resource "aws_lambda_permission" "start_job_handler" {
  count         = var.enable_websocket_api ? 1 : 0
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_job_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.websocket_api_gateway[0].api_execution_arn}/*/$default"
}

# --- HTTP API Gateway ---
resource "aws_apigatewayv2_api" "http_api" {
  name               = "${var.app_name}-http-api-${var.environment}-${var.region}"
  protocol_type      = "HTTP"
  cors_configuration {
    allow_origins     = var.api_gateway_cors_origins
    allow_methods     = var.api_gateway_cors_methods
    allow_headers     = var.api_gateway_cors_headers
    allow_credentials = true
  }
}

resource "aws_apigatewayv2_vpc_link" "http_api" {
  name               = "${var.app_name}-http-api-${var.environment}-${var.region}-vpclink"
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.http_api_vpclink_sg.id]
}

resource "aws_apigatewayv2_integration" "http_api" {
  api_id               = aws_apigatewayv2_api.http_api.id
  integration_type     = "HTTP_PROXY"
  integration_uri      = aws_lb_listener.backend_tcp.arn
  integration_method   = "ANY"
  connection_type      = "VPC_LINK"
  connection_id        = aws_apigatewayv2_vpc_link.http_api.id
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

resource "aws_security_group" "http_api_vpclink_sg" {
  name        = "${var.app_name}-http-api-${var.environment}-${var.region}-vpclink-sg"
  description = "Allow traffic from HTTP API Gateway VPC Link"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
