# Development Environment Configuration
# Cost-optimized for initial development and testing

# Basic Configuration
environment = "dev"
domain_name = "dev.xelta.ai"

# Cost Optimization: Single region deployment
enable_multi_region = false
primary_region = "ap-south-1"  # Optimized for Indian market

# Cost Optimization: Disable Redis for dev
enable_redis = false
redis_enabled_environments = ["uat", "prod"]

# Cost Optimization: Minimal resources for dev
ecs_task_cpu = {
  dev  = 256
  uat  = 512
  prod = 1024
}

ecs_task_memory = {
  dev  = 512
  uat  = 1024
  prod = 2048
}

ecs_desired_count = {
  dev  = 1
  uat  = 2
  prod = 3
}

ecs_max_capacity = {
  dev  = 2
  uat  = 5
  prod = 10
}

# Cost Optimization: Enable Fargate Spot for dev
ecs_fargate_spot_enabled = true

# Cost Optimization: Single NAT Gateway
single_nat_gateway = true
enable_nat_gateway = true

# Cost Optimization: Minimal Lambda resources
lambda_memory_size = {
  dev  = 128
  uat  = 256
  prod = 512
}

lambda_timeout = 30

# Cost Optimization: Pay-per-request DynamoDB
dynamodb_billing_mode = "PAY_PER_REQUEST"

# Monitoring: Disable detailed monitoring for cost savings
enable_detailed_monitoring = false

# Cost Alerts: Enable with low threshold for dev
enable_cost_alerts = true
monthly_cost_alert_threshold = 100  # Alert at $100/month for dev

# Retention: Short retention for dev
backup_retention_days = {
  dev  = 7
  uat  = 14
  prod = 30
}

log_retention_days = {
  dev  = 7
  uat  = 14
  prod = 30
}

# WebSocket API: Enable for development testing
enable_websocket_api = true

# CORS Configuration for development
api_gateway_cors_origins = ["https://dev.xelta.ai", "http://localhost:3000"]
api_gateway_cors_methods = ["*"]
api_gateway_cors_headers = ["*"]

# Docker Images for development
frontend_images = {
  "ap-south-1" = "nginx:latest"
}

backend_images = {
  "ap-south-1" = "node:16-alpine"
}

# VPC Configuration
vpc_cidr_blocks = {
  "ap-south-1" = "10.2.0.0/16"
}

# Redis Configuration (if enabled later)
redis_node_type = "cache.t3.micro"
redis_num_cache_nodes = 1