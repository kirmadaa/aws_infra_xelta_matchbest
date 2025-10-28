# Production Environment Configuration
# Full-featured deployment with high availability and performance

# Basic Configuration
environment = "prod"
domain_name = "xelta.ai"

# Multi-region deployment for high availability
enable_multi_region = true
regions = ["us-east-1", "eu-central-1", "ap-south-1"]
primary_region = "ap-south-1"

# Enable all features for production
enable_redis = true
redis_enabled_environments = ["uat", "prod"]

# Production-grade resource sizing
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

# No Fargate Spot for production (stability)
ecs_fargate_spot_enabled = false

# Production networking
single_nat_gateway = false  # Multiple NAT Gateways for HA
enable_nat_gateway = true

# Production Lambda configuration
lambda_memory_size = {
  dev  = 128
  uat  = 256
  prod = 512
}

lambda_timeout = 60  # Longer timeout for production workloads

# DynamoDB with provisioned capacity for predictable performance
dynamodb_billing_mode = "PAY_PER_REQUEST"  # Start with on-demand, can switch later

# Full monitoring for production
enable_detailed_monitoring = true

# Production cost alerts
enable_cost_alerts = true
monthly_cost_alert_threshold = 1000  # Alert at $1000/month for prod

# Production retention policies
backup_retention_days = {
  dev  = 7
  uat  = 14
  prod = 90  # 3 months for production
}

log_retention_days = {
  dev  = 7
  uat  = 14
  prod = 90  # 3 months for production
}

# Enable WebSocket API for real-time features
enable_websocket_api = true

# Production CORS - restrictive
api_gateway_cors_origins = ["https://xelta.ai", "https://www.xelta.ai"]
api_gateway_cors_methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
api_gateway_cors_headers = ["Content-Type", "Authorization", "X-Amz-Date", "X-Api-Key"]

# Production Docker Images
frontend_images = {
  "us-east-1"    = "your-registry/xelta-frontend:prod"
  "eu-central-1" = "your-registry/xelta-frontend:prod"
  "ap-south-1"   = "your-registry/xelta-frontend:prod"
}

backend_images = {
  "us-east-1"    = "your-registry/xelta-backend:prod"
  "eu-central-1" = "your-registry/xelta-backend:prod"
  "ap-south-1"   = "your-registry/xelta-backend:prod"
}

# Multi-region VPC configuration
vpc_cidr_blocks = {
  "us-east-1"    = "10.0.0.0/16"
  "eu-central-1" = "10.1.0.0/16"
  "ap-south-1"   = "10.2.0.0/16"
}

# Production Redis configuration
redis_node_type = "cache.t3.medium"  # Larger instance for production
redis_num_cache_nodes = 2  # Multiple nodes for HA