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

variable "frontend_image" {
  description = "Docker image for the frontend service"
  type        = string
  default     = "nginx:latest" # Replace with your default frontend image
}

variable "backend_image" {
  description = "Docker image for the backend service"
  type        = string
  default     = "nginx:latest" # Replace with your default backend image
}
