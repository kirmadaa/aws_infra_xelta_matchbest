variable "enable_xelta" {
  description = "Enable the Xelta application stack"
  type        = bool
  default     = false
}

variable "environment" {
  description = "Environment name (dev, uat, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "frontend_image" {
  description = "Docker image for the frontend service"
  type        = string
}

variable "backend_image" {
  description = "Docker image for the backend service"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}
