variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the ECS cluster"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Fargate tasks"
  type        = list(string)
}

variable "alb_target_group_arn" {
  description = "ARN of the ALB Target Group to attach the service to"
  type        = string
}

variable "container_image" {
  description = "Docker image for the service"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 8080
}

variable "service_name" {
  description = "Name for the ECS service and task definition"
  type        = string
}
