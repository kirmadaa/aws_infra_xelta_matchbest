variable "environment" {
  description = "The deployment environment (e.g., dev, uat, prod)"
  type        = string
}

variable "region" {
  description = "The AWS region for the deployment"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the NLB and ECS tasks"
  type        = list(string)
}

variable "ecs_service_security_group_id" {
  description = "The ID of the security group for the ECS service"
  type        = string
}

variable "nlb_listener_arn" {
  description = "The ARN of the NLB listener to integrate with"
  type        = string
}

variable "connection_timeout_minutes" {
  description = "WebSocket idle connection timeout in minutes (max 10)"
  type        = number
  default     = 10
}