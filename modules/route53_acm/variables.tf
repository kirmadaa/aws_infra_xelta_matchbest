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
}

variable "cdn_zone_id" {
  description = "CloudFront distribution Route53 zone ID"
  type        = string
}

variable "regional_alb_endpoints" {
  description = "A map of region to ALB endpoints"
  type        = map(object({
    dns_name = string
    zone_id  = string
  }))
  default = {}
}
