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

variable "enable_xelta" {
  description = "Enable the Xelta application stack"
  type        = bool
  default     = false
}

variable "frontend_images" {
  description = "Docker images for the frontend service, keyed by region"
  type        = map(string)
}

variable "backend_images" {
  description = "Docker images for the backend service, keyed by region"
  type        = map(string)
}
