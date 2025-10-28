variable "environment" {
  description = "Environment name (e.g., 'dev', 'uat', 'prod')"
  type        = string
}

variable "domain_name" {
  description = "The domain name for the CDN"
  type        = string
}

variable "route53_zone_id" {
  description = "The ID of the Route53 hosted zone"
  type        = string
}

variable "origins" {
  description = "A map of region to API Gateway endpoints"
  type        = map(string)
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate for the CDN (must be in us-east-1)"
  type        = string
}

variable "logging_bucket" {
  description = "Name of the S3 bucket for access logs"
  type        = string
}

variable "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL to associate with the CDN"
  type        = string
}
