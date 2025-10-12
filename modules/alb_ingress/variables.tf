variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the ALB"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB"
  type        = list(string)
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate for the ALB listener"
  type        = string
}

variable "target_groups" {
  description = "A map of target groups to create"
  type = map(object({
    port              = number
    protocol          = string
    health_check_path = string
  }))
  default = {}
}

variable "listener_rules" {
  description = "A map of listener rules to create"
  type = map(object({
    priority         = number
    path_patterns    = list(string)
    target_group_key = string
  }))
  default = {}
}

variable "default_target_group_key" {
  description = "The key of the target group to use for the default listener action"
  type        = string
  default     = "frontend"
}
