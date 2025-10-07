variable "project_name" {
  description = "The name of the project, used for tagging resources."
  type        = string
}

variable "domain_name" {
  description = "The main domain for the environment (e.g., 'dev.myapp.com')."
  type        = string
}

variable "parent_zone_id" {
  description = "The Route 53 hosted zone ID for the parent domain."
  type        = string
}

variable "alb_security_group_id" {
  description = "The ID of the security group for the Application Load Balancer."
  type        = string
}