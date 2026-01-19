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

variable "sqs_queue_url" {
  description = "The URL of the SQS queue to send messages to"
  type        = string
}

variable "sqs_role_arn" {
  description = "The ARN of the IAM role for API Gateway to send messages to SQS"
  type        = string
}

variable "custom_routes" {
  description = "A list of custom routes to create"
  type        = list(string)
  default     = []
}
