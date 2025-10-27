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

variable "connect_lambda_arn" {
  description = "The ARN of the Connect Lambda function"
  type        = string
}

variable "default_lambda_arn" {
  description = "The ARN of the Default Lambda function"
  type        = string
}

variable "disconnect_lambda_arn" {
  description = "The ARN of the Disconnect Lambda function"
  type        = string
}

variable "custom_routes" {
  description = "A list of custom routes to create"
  type        = list(string)
  default     = []
}

variable "cloudwatch_log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
}
