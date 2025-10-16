# modules/websocket_api_gateway/variables.tf

variable "environment" {
  description = "The deployment environment (e.g., dev, uat, prod)"
  type        = string
}

variable "region" {
  description = "The AWS region for the deployment"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the API Gateway will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "A list of private subnet IDs for the VPC Link"
  type        = list(string)
}

variable "ecs_service_security_group_id" {
  description = "The security group ID for the ECS service to allow traffic from the VPC Link"
  type        = string
}

variable "nlb_listener_arn" {
  description = "The ARN of the Network Load Balancer listener to integrate with"
  type        = string
}

variable "custom_routes" {
  description = "A list of custom routes to create"
  type        = list(string)
  default     = []
}