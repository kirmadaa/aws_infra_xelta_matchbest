variable "environment" {
  description = "Environment name (e.g., 'dev', 'uat', 'prod')"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "backend_ecs_service_name" {
  description = "Name of the backend ECS service"
  type        = string
}

variable "frontend_ecs_service_name" {
  description = "Name of the frontend ECS service"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer"
  type        = string
}
