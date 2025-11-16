variable "environment" {
  description = "Environment name (dev, uat, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "service_name" {
  description = "Name of the microservice"
  type        = string
}

variable "docker_image" {
  description = "Docker image for the service"
  type        = string
}

variable "cpu" {
  description = "CPU units for the service"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory for the service"
  type        = number
  default     = 512
}

variable "container_port" {
  description = "Container port to expose"
  type        = number
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Minimum number of tasks for autoscaling"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Maximum number of tasks for autoscaling"
  type        = number
  default     = 10
}

variable "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  type        = string
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "ecs_service_security_group_id" {
  description = "ID of the security group for the ECS service"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the target group"
  type        = string
}
