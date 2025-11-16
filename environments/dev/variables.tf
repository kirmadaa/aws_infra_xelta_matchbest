variable "environment" {
  description = "Environment name (dev, uat, prod)"
  type        = string
}

variable "domain_name" {
  description = "Root domain name managed in Route53"
  type        = string
}

variable "vpc_cidr_blocks" {
  description = "CIDR blocks for VPCs in each region"
  type        = map(string)
}

variable "frontend_images" {
  description = "Docker images for the frontend service, keyed by region"
  type        = map(string)
}

variable "backend_images" {
  description = "Docker images for the backend service, keyed by region"
  type        = map(string)
}

variable "xelta_region_config" {
  description = "Control which regions Xelta is deployed to"
  type        = map(bool)
  default     = {
    "us-east-1"    = true
    "eu-central-1" = true
    "ap-south-1"   = true
  }
}
