variable "project_name" {
  description = "The name of the project, used for tagging resources."
  type        = string
}

variable "domain_name" {
  description = "The full domain name for which the certificate will be issued (e.g., 'www.xelta.ai')."
  type        = string
}

variable "alb_security_group_id" {
  description = "The ID of the security group for the Application Load Balancer."
  type        = string
}