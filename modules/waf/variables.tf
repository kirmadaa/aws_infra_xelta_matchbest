variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "alb_arn" {
  description = "ARN of the ALB to associate the WAF with"
  type        = string
}
