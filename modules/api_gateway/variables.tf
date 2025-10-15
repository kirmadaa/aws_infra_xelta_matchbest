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

variable "frontend_nlb_listener_arn" {
  description = "ARN of the NLB listener for the frontend"
  type        = string
}

variable "backend_nlb_listener_arn" {
  description = "ARN of the NLB listener for the backend"
  type        = string
}

variable "sqs_queue_url" {
  description = "URL of the SQS queue for job submission"
  type        = string
  default     = ""
}

variable "sqs_queue_arn" {
  description = "ARN of the SQS queue for job submission"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "The custom domain name for the API Gateway"
  type        = string
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate for the custom domain"
  type        = string
}

variable "enable_sqs_integration" {
  description = "Enable the SQS integration for the API Gateway"
  type        = bool
  default     = false
}