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

variable "eks_version" {
  description = "Kubernetes version for EKS clusters"
  type        = string
  default     = "1.28"
}

variable "eks_node_instance_types" {
  description = "EC2 instance types for EKS node groups"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_desired_size" {
  description = "Desired number of nodes per EKS node group"
  type        = number
  default     = 2
}

variable "eks_node_min_size" {
  description = "Minimum number of nodes per EKS node group"
  type        = number
  default     = 2
}

variable "eks_node_max_size" {
  description = "Maximum number of nodes per EKS node group"
  type        = number
  default     = 4
}

variable "aurora_instance_class" {
  description = "Instance class for Aurora PostgreSQL"
  type        = string
  default     = "db.t3.medium"
}

variable "aurora_instance_count" {
  description = "Number of Aurora instances (1 writer + n readers)"
  type        = number
  default     = 2
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

variable "enable_aurora" {
  description = "Enable Aurora PostgreSQL deployment (set false for dev cost savings)"
  type        = bool
  default     = true
}

variable "enable_redis" {
  description = "Enable ElastiCache Redis deployment"
  type        = bool
  default     = true
}