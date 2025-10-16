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

variable "nlb_arn" {
  description = "The ARN of the Network Load Balancer to integrate with"
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