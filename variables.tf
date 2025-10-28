variable "environment" {
  description = "Environment name (dev, uat, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "Environment must be dev, uat, or prod."
  }
}

variable "domain_name" {
  description = "Root domain name managed in Route53"
  type        = string
  default     = "xelta.ai"
}

variable "regions" {
  description = "AWS regions for multi-region deployment"
  type        = list(string)
  default     = ["us-east-1", "eu-central-1", "ap-south-1"]
}

# Cost Optimization: Single region for dev
variable "enable_multi_region" {
  description = "Enable multi-region deployment. Set to false for cost optimization in dev"
  type        = bool
  default     = true
}

variable "primary_region" {
  description = "Primary region for single-region deployments"
  type        = string
  default     = "ap-south-1"  # Optimized for Indian market
}

variable "vpc_cidr_blocks" {
  description = "CIDR blocks for VPCs in each region"
  type        = map(string)
  default = {
    "us-east-1"    = "10.0.0.0/16"
    "eu-central-1" = "10.1.0.0/16"
    "ap-south-1"   = "10.2.0.0/16"
  }
}

# Cost Optimization: Environment-based Redis configuration
variable "redis_node_type" {
  description = "Node type for ElastiCache Redis"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_cache_nodes" {
  description = "Number of cache nodes in Redis cluster"
  type        = number
  default     = 1
}

variable "enable_redis" {
  description = "Enable ElastiCache Redis deployment"
  type        = bool
  default     = true
}

# Cost Optimization: Conditional Redis based on environment
variable "redis_enabled_environments" {
  description = "Environments where Redis should be enabled"
  type        = list(string)
  default     = ["uat", "prod"]  # Disable for dev to save costs
}

variable "enable_websocket_api" {
  description = "Enable WebSocket API Gateway deployment"
  type        = bool
  default     = true
}

# Cost Optimization: NAT Gateway configuration
variable "single_nat_gateway" {
  description = "Use single NAT Gateway per region instead of one per AZ for cost optimization"
  type        = bool
  default     = true  # Always true for cost optimization
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway (disable for dev to save costs, use NAT instances instead)"
  type        = bool
  default     = true
}

# Cost Optimization: ECS Fargate configuration
variable "ecs_fargate_spot_enabled" {
  description = "Enable Fargate Spot for cost optimization (dev environment only)"
  type        = bool
  default     = false
}

variable "ecs_task_cpu" {
  description = "CPU units for ECS tasks (256, 512, 1024, etc.)"
  type        = map(number)
  default = {
    dev  = 256   # Minimal for dev
    uat  = 512   # Medium for UAT
    prod = 1024  # Higher for prod
  }
}

variable "ecs_task_memory" {
  description = "Memory for ECS tasks in MB"
  type        = map(number)
  default = {
    dev  = 512   # Minimal for dev
    uat  = 1024  # Medium for UAT
    prod = 2048  # Higher for prod
  }
}

variable "ecs_desired_count" {
  description = "Desired count of ECS tasks per service"
  type        = map(number)
  default = {
    dev  = 1     # Single instance for dev
    uat  = 2     # Standard for UAT
    prod = 3     # High availability for prod
  }
}

variable "ecs_max_capacity" {
  description = "Maximum capacity for auto scaling"
  type        = map(number)
  default = {
    dev  = 2     # Limited scaling for dev
    uat  = 5     # Medium scaling for UAT
    prod = 10    # Full scaling for prod
  }
}

variable "frontend_images" {
  description = "Docker images for the frontend service, keyed by region"
  type        = map(string)
  default = {
    "us-east-1"    = "nginx:latest"
    "eu-central-1" = "nginx:latest"
    "ap-south-1"   = "nginx:latest"
  }
}

variable "backend_images" {
  description = "Docker images for the backend service, keyed by region"
  type        = map(string)
  default = {
    "us-east-1"    = "nginx:latest"
    "eu-central-1" = "nginx:latest"
    "ap-south-1"   = "nginx:latest"
  }
}

variable "api_gateway_cors_origins" {
  description = "List of allowed origins for the HTTP API Gateway (e.g., [\"https://xelta.ai\"]) - must include 'https://'"
  type        = list(string)
  default     = []
}

variable "api_gateway_cors_methods" {
  description = "List of allowed methods for the HTTP API Gateway (e.g., [\"GET\", \"POST\"] or [\"*\"])"
  type        = list(string)
  default     = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
}

variable "api_gateway_cors_headers" {
  description = "List of allowed headers for the HTTP API Gateway (e.g., [\"Content-Type\", \"Authorization\"] or [\"*\"])"
  type        = list(string)
  default     = ["*"]
}

# Cost Optimization: Lambda configuration
variable "lambda_memory_size" {
  description = "Memory size for Lambda functions in MB"
  type        = map(number)
  default = {
    dev  = 128   # Minimal for dev
    uat  = 256   # Standard for UAT
    prod = 512   # Higher for prod
  }
}

variable "lambda_timeout" {
  description = "Timeout for Lambda functions in seconds"
  type        = number
  default     = 30
}

# Cost Optimization: DynamoDB configuration
variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode"
  type        = string
  default     = "PAY_PER_REQUEST"  # Better for unpredictable workloads
}

# Monitoring and Cost Management
variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = false  # Disable for cost optimization in dev
}

variable "enable_cost_alerts" {
  description = "Enable cost monitoring alerts"
  type        = bool
  default     = true
}

variable "monthly_cost_alert_threshold" {
  description = "Monthly cost threshold for alerts (USD)"
  type        = number
  default     = 200  # Alert when monthly costs exceed $200
}

# Backup and retention settings
variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = map(number)
  default = {
    dev  = 7     # 1 week for dev
    uat  = 14    # 2 weeks for UAT
    prod = 30    # 1 month for prod
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = map(number)
  default = {
    dev  = 7     # 1 week for dev
    uat  = 14    # 2 weeks for UAT
    prod = 30    # 1 month for prod
  }
}