output "waf_arn" {
  description = "The ARN of the WAF Web ACL."
  value       = aws_wafv2_web_acl.main.arn
}

output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution."
  value       = aws_cloudfront_distribution.main.domain_name
}

output "subdomain_zone_id" {
  description = "The ID of the created Route 53 subdomain zone."
  value       = aws_route53_zone.subdomain.zone_id
}