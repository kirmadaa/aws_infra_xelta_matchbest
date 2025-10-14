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

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the ECS tasks"
  type        = list(string)
}

variable "min_capacity" {
  description = "Minimum number of tasks for autoscaling"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Maximum number of tasks for autoscaling"
  type        = number
  default     = 20
}

variable "cpu_target_value" {
  description = "CPU utilization target for autoscaling"
  type        = number
  default     = 70.0
}

variable "memory_target_value" {
  description = "Memory utilization target for autoscaling"
  type        = number
  default     = 80.0
}

variable "backend_image" {
  description = "Docker image for the backend service"
  type        = string
}

variable "frontend_image" {
  description = "Docker image for the frontend service"
  type        = string
}

variable "worker_image" {
  description = "Docker image for the worker service"
  type        = string
}

variable "backend_cpu" {
  description = "CPU units for the backend task"
  type        = number
  default     = 256
}

variable "backend_memory" {
  description = "Memory for the backend task"
  type        = number
  default     = 512
}

variable "backend_port" {
  description = "Port for the backend container"
  type        = number
  default     = 80
}

variable "frontend_cpu" {
  description = "CPU units for the frontend task"
  type        = number
  default     = 256
}

variable "frontend_memory" {
  description = "Memory for the frontend task"
  type        = number
  default     = 512
}

variable "frontend_port" {
  description = "Port for the frontend container"
  type        = number
  default     = 80
}
variable "public_subnet_ids" {
  description = "List of public subnet IDs for the Application Load Balancer"
  type        = list(string)
}
variable "redis_endpoint" {
  description = "The endpoint of the Redis cluster"
  type        = string
  default     = ""
}

variable "sqs_queue_arn" {
  description = "ARN of the SQS queue for jobs"
  type        = string
}

variable "sqs_queue_url" {
  description = "URL of the SQS queue for jobs"
  type        = string
}

variable "s3_outputs_bucket_arn" {
  description = "ARN of the S3 bucket for job outputs"
  type        = string
}

variable "s3_outputs_bucket_id" {
  description = "ID of the S3 bucket for job outputs"
  type        = string
}
