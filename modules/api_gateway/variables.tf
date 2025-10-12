variable "environment" {
  description = "Environment name (e.g., 'dev', 'uat', 'prod')"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the VPC Link"
  type        = list(string)
}

variable "ecs_service_security_group_id" {
  description = "ID of the security group for the ECS service"
  type        = string
}

variable "ecs_service_arn" {
  description = "ARN of the ECS service to integrate with"
  type        = string
}

variable "nlb_listener_arn" {
  description = "ARN of the NLB listener to integrate with"
  type        = string
}
