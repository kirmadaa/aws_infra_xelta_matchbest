variable "environment" {
  description = "Environment name (e.g., dev, uat, prod)"
  type        = string
}

variable "region" {
  description = "AWS region for this stack"
  type        = string
}

variable "domain_name" {
  description = "The root domain name for the application"
  type        = string
}

variable "route53_zone_id" {
  description = "The ID of the Route53 hosted zone for the domain"
  type        = string
}

# ECS & IMAGES
variable "frontend_image" {
  description = "Docker image for the frontend service"
  type        = string
}

variable "backend_image" {
  description = "Docker image for the backend service"
  type        = string
}

variable "ecs_task_cpu" {
  description = "CPU units for the ECS tasks"
  type        = number
}

variable "ecs_task_memory" {
  description = "Memory (in MiB) for the ECS tasks"
  type        = number
}

# VPC & NETWORKING
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones for the VPC"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Whether to provision a single NAT gateway for the VPC"
  type        = bool
  default     = false
}

# REDIS
variable "enable_redis" {
  description = "Whether to enable ElastiCache Redis"
  type        = bool
}

variable "redis_node_type" {
  description = "Node type for the ElastiCache Redis cluster"
  type        = string
}

variable "redis_num_cache_nodes" {
  description = "Number of nodes in the ElastiCache Redis cluster"
  type        = number
}

# API GATEWAY
variable "api_gateway_cors_origins" {
  description = "List of allowed origins for the HTTP API Gateway"
  type        = list(string)
}

variable "api_gateway_cors_methods" {
  description = "List of allowed methods for the HTTP API Gateway"
  type        = list(string)
}

variable "api_gateway_cors_headers" {
  description = "List of allowed headers for the HTTP API Gateway"
  type        = list(string)
}

# LAMBDA
variable "lambda_memory_size" {
  description = "Memory (in MiB) for the Lambda functions"
  type        = number
}

# OBSERVABILITY
variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for the ECS cluster"
  type        = bool
  default     = true
}

variable "enable_lambda_insights" {
  description = "Enable CloudWatch Lambda Insights for the Lambda functions"
  type        = bool
  default     = true
}

variable "cloudwatch_log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
}

variable "alarm_sns_topic_arn" {
  description = "ARN of the SNS topic to send CloudWatch alarms to"
  type        = string
}

variable "alarm_evaluation_periods" {
  description = "Number of periods over which to evaluate the alarm"
  type        = number
}

variable "alarm_period_seconds" {
  description = "The period (in seconds) over which to evaluate the alarm"
  type        = number
}

variable "alarm_threshold" {
  description = "The threshold for the alarm"
  type        = number
}
