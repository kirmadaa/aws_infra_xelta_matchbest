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

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "shared_cluster_id" {
  description = "ID of the shared ECS cluster"
  type        = string
}

variable "shared_cluster_name" {
  description = "Name of the shared ECS cluster"
  type        = string
}

variable "shared_listener_arn" {
  description = "ARN of the shared ALB listener"
  type        = string
}

variable "shared_alb_security_group_id" {
  description = "ID of the shared ALB security group"
  type        = string
}
