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

variable "frontend_image" {
  description = "Docker image for the frontend service"
  type        = string
}

variable "backend_image" {
  description = "Docker image for the backend service"
  type        = string
}

variable "task_cpu" {
  description = "CPU units for the ECS tasks"
  type        = number
}

variable "task_memory" {
  description = "Memory (in MiB) for the ECS tasks"
  type        = number
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for the ECS cluster"
  type        = bool
  default     = true
}

variable "cloudwatch_log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
}

variable "http_api_vpclink_sg_id" {
  description = "The ID of the security group for the HTTP API Gateway VPC Link"
  type        = string
}
# Add this new variable
variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB"
  type        = list(string)
}