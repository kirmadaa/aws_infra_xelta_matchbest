variable "app_name" {
  description = "The application name (e.g. xelta)"
  type        = string
}

variable "environment" {
  description = "The deployment environment (dev, prod, uat)"
  type        = string
}

variable "region" {
  description = "The AWS region"
  type        = string
}

# --- Shared Infrastructure Inputs ---
variable "vpc_id" {
  description = "ID of the shared VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}


variable "frontend_alb_listener_arn" {
  description = "ARN of the shared Frontend ALB Listener"
  type        = string
}

variable "backend_nlb_arn" {
  description = "ARN of the shared Backend NLB"
  type        = string
}

variable "app_port" {
  description = "Port for the application backend listener on the shared NLB"
  type        = number
  default     = 8080
}

variable "backend_nlb_dns_name" {
  description = "DNS name of the shared Backend NLB"
  type        = string
}


variable "alb_security_group_id" {
  description = "ID of the shared ALB Security Group"
  type        = string
}

variable "nlb_security_group_id" {
  description = "ID of the shared NLB Security Group"
  type        = string
}

# --- Application Specific Inputs ---

variable "frontend_image" {
  description = "Docker image for the frontend"
  type        = string
}

variable "backend_image" {
  description = "Docker image for the backend"
  type        = string
}

variable "domain_name" {
  description = "The domain name"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 Zone ID"
  type        = string
}

variable "cdn_dns_name" {
  description = "CDN DNS Name"
  type        = string
}

variable "cdn_zone_id" {
  description = "CDN Zone ID"
  type        = string
}

variable "enable_redis" {
  description = "Enable Redis"
  type        = bool
  default     = false
}

variable "redis_node_type" {
  description = "Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_cache_nodes" {
  description = "Number of Redis cache nodes"
  type        = number
  default     = 1
}

variable "enable_websocket_api" {
  description = "Enable WebSocket API"
  type        = bool
  default     = false
}

variable "api_gateway_cors_origins" {
  description = "CORS origins for API Gateway"
  type        = list(string)
  default     = ["*"]
}

variable "api_gateway_cors_methods" {
  description = "CORS methods for API Gateway"
  type        = list(string)
  default     = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
}

variable "api_gateway_cors_headers" {
  description = "CORS headers for API Gateway"
  type        = list(string)
  default     = ["Content-Type", "Authorization"]
}

variable "lambda_connect_zip_path" {
  description = "Path to the connect lambda zip file"
  type        = string
}

variable "lambda_start_job_zip_path" {
  description = "Path to the start_job lambda zip file"
  type        = string
}

variable "lambda_worker_zip_path" {
  description = "Path to the worker lambda zip file"
  type        = string
}

variable "lb_path_pattern" {
  description = "Path pattern for ALB routing (e.g. /api/*)"
  type        = string
  default     = "/*"
}

variable "lb_priority" {
  description = "Priority for ALB listener rule"
  type        = number
  default     = 100
}
