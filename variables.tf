# GLOBAL & ENVIRONMENT
variable "environment" {
  description = "The deployment environment (e.g., dev, uat, prod)."
  type        = string
}

variable "domain_name" {
  description = "The root domain name for the application (e.g., xelta.ai)."
  type        = string
}

# REGIONAL CONFIGURATION
variable "regional_configs" {
  description = "A map of configurations for each AWS region to be deployed."
  type = map(object({
    region             = string
    availability_zones = list(string)
    vpc_cidr           = string
    frontend_image     = string
    backend_image      = string
    single_nat_gateway = bool
  }))
}

# ECS & IMAGES
variable "ecs_task_cpu" {
  description = "CPU units to allocate for each ECS task."
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "Memory (in MiB) to allocate for each ECS task."
  type        = number
  default     = 512
}

# REDIS
variable "enable_redis" {
  description = "Flag to enable or disable the deployment of ElastiCache Redis."
  type        = bool
  default     = true
}

variable "redis_node_type" {
  description = "The instance type for the Redis cache nodes."
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_cache_nodes" {
  description = "The number of nodes in the Redis cluster."
  type        = number
  default     = 1
}

# API GATEWAY
variable "api_gateway_cors_origins" {
  description = "A list of allowed origins for the HTTP API Gateway CORS configuration."
  type        = list(string)
  default     = []
}

variable "api_gateway_cors_methods" {
  description = "A list of allowed methods for the HTTP API Gateway CORS configuration."
  type        = list(string)
  default     = ["*"]
}

variable "api_gateway_cors_headers" {
  description = "A list of allowed headers for the HTTP API Gateway CORS configuration."
  type        = list(string)
  default     = ["*"]
}

# LAMBDA
variable "lambda_memory_size" {
  description = "The amount of memory (in MiB) to allocate for Lambda functions."
  type        = number
  default     = 128
}

# OBSERVABILITY
variable "enable_container_insights" {
  description = "Flag to enable CloudWatch Container Insights for the ECS cluster."
  type        = bool
  default     = true
}

variable "enable_lambda_insights" {
  description = "Flag to enable CloudWatch Lambda Insights for Lambda functions."
  type        = bool
  default     = true
}

variable "cloudwatch_log_retention_days" {
  description = "The number of days to retain CloudWatch logs."
  type        = number
  default     = 30
}

variable "alarm_sns_topic_arn" {
  description = "The ARN of the SNS topic to which CloudWatch alarm notifications will be sent."
  type        = string
}

variable "alarm_evaluation_periods" {
  description = "The number of periods over which to evaluate a CloudWatch alarm."
  type        = number
  default     = 1
}

variable "alarm_period_seconds" {
  description = "The period (in seconds) over which to evaluate a CloudWatch alarm."
  type        = number
  default     = 60
}

variable "alarm_threshold" {
  description = "The threshold for CloudWatch alarms."
  type        = number
  default     = 1
}
