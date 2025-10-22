variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "domain_name" {
  description = "Domain name"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

variable "cdn_dns_name" {
  description = "CloudFront distribution DNS name"
  type        = string
  default     = null
}

variable "cdn_zone_id" {
  description = "CloudFront distribution Route53 zone ID"
  type        = string
  default     = null
}

variable "create_cdn_record" {
  description = "Whether to create the Route53 record for the CDN"
  type        = bool
  default     = false
}
