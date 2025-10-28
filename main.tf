# Data source for Route53 hosted zone
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}


# Central Logging S3 Bucket
resource "aws_s3_bucket" "access_logs" {
  provider = aws.us_east_1
  bucket   = "xelta-tf-access-logs"
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs_lifecycle" {
  provider = aws.us_east_1
  bucket   = aws_s3_bucket.access_logs.id

  rule {
    id     = "auto-delete-old-logs"
    status = "Enabled"

    expiration {
      days = 30
    }
  }
}

# Global secrets (stored in us-east-1, replicated to other regions)
module "secrets_us_east_1" {
  source    = "./modules/secrets"
  providers = { aws = aws.us_east_1 }
  environment = var.environment
}

module "secrets_eu_central_1" {
  source    = "./modules/secrets"
  providers = { aws = aws.eu_central_1 }
  environment = var.environment
}

module "secrets_ap_south_1" {
  source    = "./modules/secrets"
  providers = { aws = aws.ap_south_1 }
  environment = var.environment
}

# WAF & CDN (Global resources)
module "waf" {
  source      = "./modules/waf"
  environment = var.environment
}

module "cdn" {
  source          = "./modules/cdn"
  environment     = var.environment
  domain_name     = var.domain_name
  route53_zone_id = data.aws_route53_zone.main.zone_id
  waf_web_acl_arn = module.waf.waf_arn

  # --- FIX: Origins now point to the regional ALBs ---
  origins = {
    us-east-1    = module.ecs_service_us_east_1.frontend_alb_dns_name
    eu-central-1 = module.ecs_service_eu_central_1.frontend_alb_dns_name
    ap-south-1   = module.ecs_service_ap_south_1.frontend_alb_dns_name
  }
  # --- END FIX ---

  # ACM certificate for the CDN (must be in us-east-1)
  certificate_arn = module.route53_acm_us_east_1.certificate_arn
  logging_bucket  = aws_s3_bucket.access_logs.bucket_domain_name
}

# ==================================
# NEW SERVERLESS BACKEND COMPONENTS
# ==================================

# --- US-EAST-1 ---
resource "aws_dynamodb_table" "jobs_us_east_1" {
  provider     = aws.us_east_1
  name         = "xelta-${var.environment}-jobs-us-east-1"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "jobId"

  attribute {
    name = "jobId"
    type = "S"
  }
}

resource "aws_sqs_queue" "jobs_us_east_1" {
  provider = aws.us_east_1
  name     = "xelta-${var.environment}-jobs-us-east-1"
}

resource "aws_s3_bucket" "results_us_east_1" {
  provider = aws.us_east_1
  bucket   = "xelta-${var.environment}-results-us-east-1"
}

# --- EU-CENTRAL-1 ---
resource "aws_dynamodb_table" "jobs_eu_central_1" {
  provider     = aws.eu_central_1
  name         = "xelta-${var.environment}-jobs-eu-central-1"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "jobId"

  attribute {
    name = "jobId"
    type = "S"
  }
}

resource "aws_sqs_queue" "jobs_eu_central_1" {
  provider = aws.eu_central_1
  name     = "xelta-${var.environment}-jobs-eu-central-1"
}

resource "aws_s3_bucket" "results_eu_central_1" {
  provider = aws.eu_central_1
  bucket   = "xelta-${var.environment}-results-eu-central-1"
}

# --- AP-SOUTH-1 ---
resource "aws_dynamodb_table" "jobs_ap_south_1" {
  provider     = aws.ap_south_1
  name         = "xelta-${var.environment}-jobs-ap-south-1"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "jobId"

  attribute {
    name = "jobId"
    type = "S"
  }
}

resource "aws_sqs_queue" "jobs_ap_south_1" {
  provider = aws.ap_south_1
  name     = "xelta-${var.environment}-jobs-ap-south-1"
}

resource "aws_s3_bucket" "results_ap_south_1" {
  provider = aws.ap_south_1
  bucket   = "xelta-${var.environment}-results-ap-south-1"
}


# ===========================
# US-EAST-1 REGION RESOURCES
# ===========================

# --- IAM Role for Lambdas ---
resource "aws_iam_role" "lambda_exec_us_east_1" {
  provider = aws.us_east_1
  name     = "xelta-${var.environment}-lambda-exec-us-east-1"
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

resource "aws_iam_role_policy_attachment" "lambda_basic_execution_us_east_1" {
  provider   = aws.us_east_1
  role       = aws_iam_role.lambda_exec_us_east_1.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_policy_us_east_1" {
  provider = aws.us_east_1
  name     = "xelta-${var.environment}-lambda-policy-us-east-1"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # --- FIX: Added SQS permissions for Event Source Mapping ---
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        # --- END FIX ---
        Effect   = "Allow"
        Resource = aws_sqs_queue.jobs_us_east_1.arn
      },
      {
        Action   = ["dynamodb:PutItem"]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.jobs_us_east_1.arn
      },
      {
        Action   = ["s3:PutObject"]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.results_us_east_1.arn}/*"
      },
      {
        Action   = ["execute-api:ManageConnections"]
        Effect   = "Allow"
        Resource = "arn:aws:execute-api:us-east-1:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment_us_east_1" {
  provider   = aws.us_east_1
  role       = aws_iam_role.lambda_exec_us_east_1.name
  policy_arn = aws_iam_policy.lambda_policy_us_east_1.arn
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access_us_east_1" {
  provider   = aws.us_east_1
  role       = aws_iam_role.lambda_exec_us_east_1.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_xray_access_us_east_1" {
  provider   = aws.us_east_1
  role       = aws_iam_role.lambda_exec_us_east_1.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# --- ConnectHandler Lambda ---
resource "aws_lambda_function" "connect_handler_us_east_1" {
  provider         = aws.us_east_1
  function_name    = "xelta-${var.environment}-connect-handler-us-east-1"
  role             = aws_iam_role.lambda_exec_us_east_1.arn
  handler          = "index.handler"
  runtime          = "nodejs16.x"
  filename         = "lambda/connect.zip"
  source_code_hash = filebase64sha256("lambda/connect.zip")

  lifecycle {
    ignore_changes = all
  }

  tracing_config {
    mode = "Active"
  }
}

# --- StartJobHandler Lambda ---
resource "aws_lambda_function" "start_job_handler_us_east_1" {
  provider         = aws.us_east_1
  function_name    = "xelta-${var.environment}-start-job-handler-us-east-1"
  role             = aws_iam_role.lambda_exec_us_east_1.arn
  handler          = "index.handler"
  runtime          = "nodejs16.x"
  filename         = "lambda/start_job.zip"
  source_code_hash = filebase64sha256("lambda/start_job.zip")

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.jobs_us_east_1.name
      SQS_QUEUE_URL  = aws_sqs_queue.jobs_us_east_1.id
    }
  }

  lifecycle {
    ignore_changes = all
  }

  tracing_config {
    mode = "Active"
  }
}

resource "aws_lambda_event_source_mapping" "worker_trigger_ap_south_1" {
  provider         = aws.ap_south_1
  event_source_arn = aws_sqs_queue.jobs_ap_south_1.arn
  function_name    = aws_lambda_function.worker_ap_south_1.arn
}

resource "aws_lambda_event_source_mapping" "worker_trigger_eu_central_1" {
  provider         = aws.eu_central_1
  event_source_arn = aws_sqs_queue.jobs_eu_central_1.arn
  function_name    = aws_lambda_function.worker_eu_central_1.arn
}

resource "aws_lambda_event_source_mapping" "worker_trigger_us_east_1" {
  provider         = aws.us_east_1
  event_source_arn = aws_sqs_queue.jobs_us_east_1.arn
  function_name    = aws_lambda_function.worker_us_east_1.arn
}

# --- Worker Lambda ---
resource "aws_lambda_function" "worker_us_east_1" {
  provider         = aws.us_east_1
  function_name    = "xelta-${var.environment}-worker-us-east-1"
  role             = aws_iam_role.lambda_exec_us_east_1.arn
  handler          = "index.handler"
  runtime          = "nodejs16.x"
  filename         = "lambda/worker.zip"
  source_code_hash = filebase64sha256("lambda/worker.zip")

  vpc_config {
    subnet_ids         = module.vpc_us_east_1.private_subnet_ids
    security_group_ids = [module.ecs_service_us_east_1.worker_lambda_sg_id]
  }

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.jobs_us_east_1.name
      S3_BUCKET      = aws_s3_bucket.results_us_east_1.id
    }
  }

  lifecycle {
    ignore_changes = all
  }

  tracing_config {
    mode = "Active"
  }
}

module "vpc_us_east_1" {
  source    = "./modules/vpc"
  providers = { aws = aws.us_east_1 }

  environment        = var.environment
  region             = "us-east-1"
  vpc_cidr           = var.vpc_cidr_blocks["us-east-1"]
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  single_nat_gateway = var.environment == "dev" ? true : false
}

module "ecs_service_us_east_1" {
  source    = "./modules/ecs_service"
  providers = { aws = aws.us_east_1 }

  environment            = var.environment
  region                 = "us-east-1"
  vpc_id                 = module.vpc_us_east_1.vpc_id
  vpc_cidr               = var.vpc_cidr_blocks["us-east-1"]
  private_subnet_ids     = module.vpc_us_east_1.private_subnet_ids
  public_subnet_ids      = module.vpc_us_east_1.public_subnet_ids
  frontend_image         = var.frontend_images["us-east-1"]
  backend_image          = var.backend_images["us-east-1"]
  http_api_vpclink_sg_id = aws_security_group.http_api_vpclink_sg_us_east_1.id
}

# --- REMOVED: module "api_gateway_us_east_1" ---

module "route53_acm_us_east_1" {
  source    = "./modules/route53_acm"
  providers = { aws = aws.us_east_1 }

  environment     = var.environment
  region          = "us-east-1"
  domain_name     = var.domain_name
  route53_zone_id = data.aws_route53_zone.main.zone_id

  # Create Route53 record for the CDN
  cdn_dns_name    = module.cdn.cdn_dns_name
  cdn_zone_id     = module.cdn.cdn_zone_id
}

module "redis_us_east_1" {
  count     = var.enable_redis ? 1 : 0
  source    = "./modules/elasticache_redis"
  providers = { aws = aws.us_east_1 }

  environment                = var.environment
  region                     = "us-east-1"
  vpc_id                     = module.vpc_us_east_1.vpc_id
  private_subnet_ids         = module.vpc_us_east_1.private_subnet_ids
  node_type                  = var.redis_node_type
  num_cache_nodes            = var.redis_num_cache_nodes
  allowed_security_group_ids = [module.ecs_service_us_east_1.service_security_group_id]
}

module "websocket_api_gateway_us_east_1" {
  count     = var.enable_websocket_api ? 1 : 0
  source    = "./modules/websocket_api_gateway"
  providers = { aws = aws.us_east_1 }

  environment           = var.environment
  region                = "us-east-1"
  vpc_id                = module.vpc_us_east_1.vpc_id
  connect_lambda_arn    = aws_lambda_function.connect_handler_us_east_1.arn
  default_lambda_arn    = aws_lambda_function.start_job_handler_us_east_1.arn
  disconnect_lambda_arn = aws_lambda_function.connect_handler_us_east_1.arn # Using connect handler for disconnect as well
}

# --- NEW HTTP API Gateway ---
resource "aws_apigatewayv2_api" "http_api_us_east_1" {
  provider      = aws.us_east_1
  name          = "xelta-http-api-${var.environment}-us-east-1"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins     = var.api_gateway_cors_origins
    allow_methods     = var.api_gateway_cors_methods
    allow_headers     = var.api_gateway_cors_headers
    allow_credentials = true
  }
}

resource "aws_apigatewayv2_vpc_link" "http_api_us_east_1" {
  provider           = aws.us_east_1
  name               = "xelta-http-api-${var.environment}-us-east-1-vpclink"
  subnet_ids         = module.vpc_us_east_1.private_subnet_ids
  security_group_ids = [aws_security_group.http_api_vpclink_sg_us_east_1.id]
}

resource "aws_apigatewayv2_integration" "http_api_us_east_1" {
  provider             = aws.us_east_1
  api_id               = aws_apigatewayv2_api.http_api_us_east_1.id
  integration_type     = "HTTP_PROXY"
  integration_uri      = module.ecs_service_us_east_1.backend_nlb_listener_arn
  integration_method   = "ANY"
  connection_type      = "VPC_LINK"
  connection_id        = aws_apigatewayv2_vpc_link.http_api_us_east_1.id
}

resource "aws_apigatewayv2_route" "http_api_us_east_1" {
  provider  = aws.us_east_1
  api_id    = aws_apigatewayv2_api.http_api_us_east_1.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.http_api_us_east_1.id}"
}

resource "aws_apigatewayv2_stage" "http_api_us_east_1" {
  provider    = aws.us_east_1
  api_id      = aws_apigatewayv2_api.http_api_us_east_1.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 5000
    throttling_rate_limit  = 10000
    tracing_enabled        = true
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.http_api_us_east_1.arn
    format          = "$context.identity.sourceIp - - [$context.requestTime] \"$context.httpMethod $context.routeKey $context.protocol\" $context.status $context.responseLength $context.requestId"
  }
}

resource "aws_cloudwatch_log_group" "http_api_us_east_1" {
  provider = aws.us_east_1
  name     = "/aws/v2/http/${aws_apigatewayv2_api.http_api_us_east_1.name}"
  retention_in_days = 30
}

resource "aws_security_group" "http_api_vpclink_sg_ap_south_1" {
  provider    = aws.ap_south_1
  name        = "xelta-http-api-${var.environment}-ap-south-1-vpclink-sg"
  description = "Allow traffic from HTTP API Gateway VPC Link"
  vpc_id      = module.vpc_ap_south_1.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "http_api_vpclink_sg_eu_central_1" {
  provider    = aws.eu_central_1
  name        = "xelta-http-api-${var.environment}-eu-central-1-vpclink-sg"
  description = "Allow traffic from HTTP API Gateway VPC Link"
  vpc_id      = module.vpc_eu_central_1.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "http_api_vpclink_sg_us_east_1" {
  provider    = aws.us_east_1
  name        = "xelta-http-api-${var.environment}-us-east-1-vpclink-sg"
  description = "Allow traffic from HTTP API Gateway VPC Link"
  vpc_id      = module.vpc_us_east_1.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# ===============================
# EU-CENTRAL-1 REGION RESOURCES
# ===============================

# --- IAM Role for Lambdas ---
resource "aws_iam_role" "lambda_exec_eu_central_1" {
  provider = aws.eu_central_1
  name     = "xelta-${var.environment}-lambda-exec-eu-central-1"
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

resource "aws_iam_role_policy_attachment" "lambda_basic_execution_eu_central_1" {
  provider   = aws.eu_central_1
  role       = aws_iam_role.lambda_exec_eu_central_1.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_policy_eu_central_1" {
  provider = aws.eu_central_1
  name     = "xelta-${var.environment}-lambda-policy-eu-central-1"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # --- FIX: Added SQS permissions for Event Source Mapping ---
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        # --- END FIX ---
        Effect   = "Allow"
        Resource = aws_sqs_queue.jobs_eu_central_1.arn
      },
      {
        Action   = ["dynamodb:PutItem"]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.jobs_eu_central_1.arn
      },
      {
        Action   = ["s3:PutObject"]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.results_eu_central_1.arn}/*"
      },
      {
        Action   = ["execute-api:ManageConnections"]
        Effect   = "Allow"
        Resource = "arn:aws:execute-api:eu-central-1:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment_eu_central_1" {
  provider   = aws.eu_central_1
  role       = aws_iam_role.lambda_exec_eu_central_1.name
  policy_arn = aws_iam_policy.lambda_policy_eu_central_1.arn
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access_eu_central_1" {
  provider   = aws.eu_central_1
  role       = aws_iam_role.lambda_exec_eu_central_1.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_xray_access_eu_central_1" {
  provider   = aws.eu_central_1
  role       = aws_iam_role.lambda_exec_eu_central_1.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# --- ConnectHandler Lambda ---
resource "aws_lambda_function" "connect_handler_eu_central_1" {
  provider         = aws.eu_central_1
  function_name    = "xelta-${var.environment}-connect-handler-eu-central-1"
  role             = aws_iam_role.lambda_exec_eu_central_1.arn
  handler          = "index.handler"
  runtime          = "nodejs16.x"
  filename         = "lambda/connect.zip"
  source_code_hash = filebase64sha256("lambda/connect.zip")

  lifecycle {
    ignore_changes = all
  }

  tracing_config {
    mode = "Active"
  }
}

# --- StartJobHandler Lambda ---
resource "aws_lambda_function" "start_job_handler_eu_central_1" {
  provider         = aws.eu_central_1
  function_name    = "xelta-${var.environment}-start-job-handler-eu-central-1"
  role             = aws_iam_role.lambda_exec_eu_central_1.arn
  handler          = "index.handler"
  runtime          = "nodejs16.x"
  filename         = "lambda/start_job.zip"
  source_code_hash = filebase64sha256("lambda/start_job.zip")

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.jobs_eu_central_1.name
      SQS_QUEUE_URL  = aws_sqs_queue.jobs_eu_central_1.id
    }
  }

  lifecycle {
    ignore_changes = all
  }

  tracing_config {
    mode = "Active"
  }
}

# --- Worker Lambda ---
resource "aws_lambda_function" "worker_eu_central_1" {
  provider         = aws.eu_central_1
  function_name    = "xelta-${var.environment}-worker-eu-central-1"
  role             = aws_iam_role.lambda_exec_eu_central_1.arn
  handler          = "index.handler"
  runtime          = "nodejs16.x"
  filename         = "lambda/worker.zip"
  source_code_hash = filebase64sha256("lambda/worker.zip")

  vpc_config {
    subnet_ids         = module.vpc_eu_central_1.private_subnet_ids
    security_group_ids = [module.ecs_service_eu_central_1.worker_lambda_sg_id]
  }

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.jobs_eu_central_1.name
      S3_BUCKET      = aws_s3_bucket.results_eu_central_1.id
    }
  }

  lifecycle {
    ignore_changes = all
  }

  tracing_config {
    mode = "Active"
  }
}

module "vpc_eu_central_1" {
  source    = "./modules/vpc"
  providers = { aws = aws.eu_central_1 }

  environment        = var.environment
  region             = "eu-central-1"
  vpc_cidr           = var.vpc_cidr_blocks["eu-central-1"]
  availability_zones = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  single_nat_gateway = var.environment == "dev" ? true : false
}

module "ecs_service_eu_central_1" {
  source    = "./modules/ecs_service"
  providers = { aws = aws.eu_central_1 }

  environment            = var.environment
  region                 = "eu-central-1"
  vpc_id                 = module.vpc_eu_central_1.vpc_id
  vpc_cidr               = var.vpc_cidr_blocks["eu-central-1"]
  private_subnet_ids     = module.vpc_eu_central_1.private_subnet_ids
  public_subnet_ids      = module.vpc_eu_central_1.public_subnet_ids
  frontend_image         = var.frontend_images["eu-central-1"]
  backend_image          = var.backend_images["eu-central-1"]
  http_api_vpclink_sg_id = aws_security_group.http_api_vpclink_sg_eu_central_1.id
}

# --- REMOVED: module "api_gateway_eu_central_1" ---

module "redis_eu_central_1" {
  count     = var.enable_redis ? 1 : 0
  source    = "./modules/elasticache_redis"
  providers = { aws = aws.eu_central_1 }

  environment                = var.environment
  region                     = "eu-central-1"
  vpc_id                     = module.vpc_eu_central_1.vpc_id
  private_subnet_ids         = module.vpc_eu_central_1.private_subnet_ids
  node_type                  = var.redis_node_type
  num_cache_nodes            = var.redis_num_cache_nodes
  allowed_security_group_ids = [module.ecs_service_eu_central_1.service_security_group_id]
}

module "websocket_api_gateway_eu_central_1" {
  count     = var.enable_websocket_api ? 1 : 0
  source    = "./modules/websocket_api_gateway"
  providers = { aws = aws.eu_central_1 }

  environment           = var.environment
  region                = "eu-central-1"
  vpc_id                = module.vpc_eu_central_1.vpc_id
  connect_lambda_arn    = aws_lambda_function.connect_handler_eu_central_1.arn
  default_lambda_arn    = aws_lambda_function.start_job_handler_eu_central_1.arn
  disconnect_lambda_arn = aws_lambda_function.connect_handler_eu_central_1.arn # Using connect handler for disconnect as well
}

# --- NEW HTTP API Gateway ---
resource "aws_apigatewayv2_api" "http_api_eu_central_1" {
  provider      = aws.eu_central_1
  name          = "xelta-http-api-${var.environment}-eu-central-1"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins     = var.api_gateway_cors_origins
    allow_methods     = var.api_gateway_cors_methods
    allow_headers     = var.api_gateway_cors_headers
    allow_credentials = true
  }
}

resource "aws_apigatewayv2_vpc_link" "http_api_eu_central_1" {
  provider           = aws.eu_central_1
  name               = "xelta-http-api-${var.environment}-eu-central-1-vpclink"
  subnet_ids         = module.vpc_eu_central_1.private_subnet_ids
  security_group_ids = [aws_security_group.http_api_vpclink_sg_eu_central_1.id]
}

resource "aws_apigatewayv2_integration" "http_api_eu_central_1" {
  provider             = aws.eu_central_1
  api_id               = aws_apigatewayv2_api.http_api_eu_central_1.id
  integration_type     = "HTTP_PROXY"
  integration_uri      = module.ecs_service_eu_central_1.backend_nlb_listener_arn
  integration_method   = "ANY"
  connection_type      = "VPC_LINK"
  connection_id        = aws_apigatewayv2_vpc_link.http_api_eu_central_1.id
}

resource "aws_apigatewayv2_route" "http_api_eu_central_1" {
  provider  = aws.eu_central_1
  api_id    = aws_apigatewayv2_api.http_api_eu_central_1.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.http_api_eu_central_1.id}"
}

resource "aws_apigatewayv2_stage" "http_api_eu_central_1" {
  provider    = aws.eu_central_1
  api_id      = aws_apigatewayv2_api.http_api_eu_central_1.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 5000
    throttling_rate_limit  = 10000
    tracing_enabled        = true
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.http_api_eu_central_1.arn
    format          = "$context.identity.sourceIp - - [$context.requestTime] \"$context.httpMethod $context.routeKey $context.protocol\" $context.status $context.responseLength $context.requestId"
  }
}

resource "aws_cloudwatch_log_group" "http_api_eu_central_1" {
  provider = aws.eu_central_1
  name     = "/aws/v2/http/${aws_apigatewayv2_api.http_api_eu_central_1.name}"
  retention_in_days = 30
}


# ============================
# AP-SOUTH-1 REGION RESOURCES
# ============================

# --- IAM Role for Lambdas ---
resource "aws_iam_role" "lambda_exec_ap_south_1" {
  provider = aws.ap_south_1
  name     = "xelta-${var.environment}-lambda-exec-ap_south_1"
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

resource "aws_iam_role_policy_attachment" "lambda_basic_execution_ap_south_1" {
  provider   = aws.ap_south_1
  role       = aws_iam_role.lambda_exec_ap_south_1.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_policy_ap_south_1" {
  provider = aws.ap_south_1
  name     = "xelta-${var.environment}-lambda-policy-ap_south_1"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # --- FIX: Added SQS permissions for Event Source Mapping ---
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        # --- END FIX ---
        Effect   = "Allow"
        Resource = aws_sqs_queue.jobs_ap_south_1.arn
      },
      {
        Action   = ["dynamodb:PutItem"]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.jobs_ap_south_1.arn
      },
      {
        Action   = ["s3:PutObject"]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.results_ap_south_1.arn}/*"
      },
      {
        Action   = ["execute-api:ManageConnections"]
        Effect   = "Allow"
        Resource = "arn:aws:execute-api:ap-south-1:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment_ap_south_1" {
  provider   = aws.ap_south_1
  role       = aws_iam_role.lambda_exec_ap_south_1.name
  policy_arn = aws_iam_policy.lambda_policy_ap_south_1.arn
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access_ap_south_1" {
  provider   = aws.ap_south_1
  role       = aws_iam_role.lambda_exec_ap_south_1.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_xray_access_ap_south_1" {
  provider   = aws.ap_south_1
  role       = aws_iam_role.lambda_exec_ap_south_1.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# --- ConnectHandler Lambda ---
resource "aws_lambda_function" "connect_handler_ap_south_1" {
  provider         = aws.ap_south_1
  function_name    = "xelta-${var.environment}-connect-handler-ap_south_1"
  role             = aws_iam_role.lambda_exec_ap_south_1.arn
  handler          = "index.handler"
  runtime          = "nodejs16.x"
  filename         = "lambda/connect.zip"
  source_code_hash = filebase64sha256("lambda/connect.zip")

  lifecycle {
    ignore_changes = all
  }

  tracing_config {
    mode = "Active"
  }
}

# --- StartJobHandler Lambda ---
resource "aws_lambda_function" "start_job_handler_ap_south_1" {
  provider         = aws.ap_south_1
  function_name    = "xelta-${var.environment}-start-job-handler-ap_south_1"
  role             = aws_iam_role.lambda_exec_ap_south_1.arn
  handler          = "index.handler"
  runtime          = "nodejs16.x"
  filename         = "lambda/start_job.zip"
  source_code_hash = filebase64sha256("lambda/start_job.zip")

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.jobs_ap_south_1.name
      SQS_QUEUE_URL  = aws_sqs_queue.jobs_ap_south_1.id
    }
  }

  lifecycle {
    ignore_changes = all
  }

  tracing_config {
    mode = "Active"
  }
}

# --- Worker Lambda ---
resource "aws_lambda_function" "worker_ap_south_1" {
  provider         = aws.ap_south_1
  function_name    = "xelta-${var.environment}-worker-ap_south_1"
  role             = aws_iam_role.lambda_exec_ap_south_1.arn
  handler          = "index.handler"
  runtime          = "nodejs16.x"
  filename         = "lambda/worker.zip" # <-- FIX: This was missing
  source_code_hash = filebase64sha256("lambda/worker.zip")

  vpc_config {
    subnet_ids         = module.vpc_ap_south_1.private_subnet_ids
    security_group_ids = [module.ecs_service_ap_south_1.worker_lambda_sg_id]
  }

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.jobs_ap_south_1.name
      S3_BUCKET      = aws_s3_bucket.results_ap_south_1.id
    }
  }

  lifecycle {
    ignore_changes = all
  }

  tracing_config {
    mode = "Active"
  }
}

module "vpc_ap_south_1" {
  source    = "./modules/vpc"
  providers = { aws = aws.ap_south_1 }

  environment        = var.environment
  region             = "ap-south-1"
  vpc_cidr           = var.vpc_cidr_blocks["ap-south-1"]
  availability_zones = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
  single_nat_gateway = var.environment == "dev" ? true : false
}

module "ecs_service_ap_south_1" {
  source    = "./modules/ecs_service"
  providers = { aws = aws.ap_south_1 }

  environment            = var.environment
  region                 = "ap-south-1"
  vpc_id                 = module.vpc_ap_south_1.vpc_id
  vpc_cidr               = var.vpc_cidr_blocks["ap-south-1"]
  private_subnet_ids     = module.vpc_ap_south_1.private_subnet_ids
  public_subnet_ids      = module.vpc_ap_south_1.public_subnet_ids
  frontend_image         = var.frontend_images["ap-south-1"]
  backend_image          = var.backend_images["ap-south-1"]
  http_api_vpclink_sg_id = aws_security_group.http_api_vpclink_sg_ap_south_1.id
}

# --- REMOVED: module "api_gateway_ap_south_1" ---

module "redis_ap_south_1" {
  count     = var.enable_redis ? 1 : 0
  source    = "./modules/elasticache_redis"
  providers = { aws = aws.ap_south_1 }

  environment                = var.environment
  region                     = "ap-south-1"
  vpc_id                     = module.vpc_ap_south_1.vpc_id
  private_subnet_ids         = module.vpc_ap_south_1.private_subnet_ids
  node_type                  = var.redis_node_type
  num_cache_nodes            = var.redis_num_cache_nodes
  allowed_security_group_ids = [module.ecs_service_ap_south_1.service_security_group_id]
}

module "websocket_api_gateway_ap_south_1" {
  count     = var.enable_websocket_api ? 1 : 0
  source    = "./modules/websocket_api_gateway"
  providers = { aws = aws.ap_south_1 }

  environment           = var.environment
  region                = "ap-south-1"
  vpc_id                = module.vpc_ap_south_1.vpc_id
  connect_lambda_arn    = aws_lambda_function.connect_handler_ap_south_1.arn
  default_lambda_arn    = aws_lambda_function.start_job_handler_ap_south_1.arn
  disconnect_lambda_arn = aws_lambda_function.connect_handler_ap_south_1.arn # Using connect handler for disconnect as well
}

# --- NEW HTTP API Gateway ---
resource "aws_apigatewayv2_api" "http_api_ap_south_1" {
  provider      = aws.ap_south_1
  name          = "xelta-http-api-${var.environment}-ap-south-1"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins     = var.api_gateway_cors_origins
    allow_methods     = var.api_gateway_cors_methods
    allow_headers     = var.api_gateway_cors_headers
    allow_credentials = true
  }
}

resource "aws_apigatewayv2_vpc_link" "http_api_ap_south_1" {
  provider           = aws.ap_south_1
  name               = "xelta-http-api-${var.environment}-ap-south-1-vpclink"
  subnet_ids         = module.vpc_ap_south_1.private_subnet_ids
  security_group_ids = [aws_security_group.http_api_vpclink_sg_ap_south_1.id]
}

resource "aws_apigatewayv2_integration" "http_api_ap_south_1" {
  provider             = aws.ap_south_1
  api_id               = aws_apigatewayv2_api.http_api_ap_south_1.id
  integration_type     = "HTTP_PROXY"
  integration_uri      = module.ecs_service_ap_south_1.backend_nlb_listener_arn
  integration_method   = "ANY"
  connection_type      = "VPC_LINK"
  connection_id        = aws_apigatewayv2_vpc_link.http_api_ap_south_1.id
}

resource "aws_apigatewayv2_route" "http_api_ap_south_1" {
  provider  = aws.ap_south_1
  api_id    = aws_apigatewayv2_api.http_api_ap_south_1.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.http_api_ap_south_1.id}"
}

resource "aws_apigatewayv2_stage" "http_api_ap_south_1" {
  provider    = aws.ap_south_1
  api_id      = aws_apigatewayv2_api.http_api_ap_south_1.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 5000
    throttling_rate_limit  = 10000
    tracing_enabled        = true
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.http_api_ap_south_1.arn
    format          = "$context.identity.sourceIp - - [$context.requestTime] \"$context.httpMethod $context.routeKey $context.protocol\" $context.status $context.responseLength $context.requestId"
  }
}

resource "aws_cloudwatch_log_group" "http_api_ap_south_1" {
  provider = aws.ap_south_1
  name     = "/aws/v2/http/${aws_apigatewayv2_api.http_api_ap_south_1.name}"
  retention_in_days = 30
}