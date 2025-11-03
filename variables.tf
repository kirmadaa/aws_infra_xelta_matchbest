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

variable "vpc_cidr_blocks" {
  description = "CIDR blocks for VPCs in each region"
  type        = map(string)
  default = {
    "us-east-1"    = "10.0.0.0/16"
    "eu-central-1" = "10.1.0.0/16"
    "ap-south-1"   = "10.2.0.0/16"
  }
}

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

variable "enable_websocket_api" {
  description = "Enable WebSocket API Gateway deployment"
  type        = bool
  default     = true
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

variable "enable_ec2_nat_instance" {
  description = "Use a t4g.micro EC2 instance as a NAT device instead of the managed NAT Gateway for cost savings."
  type        = bool
  default     = false
}