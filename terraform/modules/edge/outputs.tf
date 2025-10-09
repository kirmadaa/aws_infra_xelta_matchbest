output "waf_arn" {
  description = "The ARN of the WAF Web ACL to be used in the Kubernetes Ingress manifest."
  value       = aws_wafv2_web_acl.main.arn
}

output "certificate_arn" {
  description = "The ARN of the ACM certificate to be used by the ALB."
  value       = aws_acm_certificate.main.arn
}

# These outputs are for the manual DNS validation step
output "acm_certificate_validation_cname_name" {
  description = "The CNAME record name required for ACM certificate validation."
  value       = tolist(aws_acm_certificate.main.domain_validation_options)[0].resource_record_name
}

output "acm_certificate_validation_cname_value" {
  description = "The CNAME record value required for ACM certificate validation."
  value       = tolist(aws_acm_certificate.main.domain_validation_options)[0].resource_record_value
}

output "acm_certificate_validation_cname_type" {
  description = "The record type required for ACM certificate validation."
  value       = tolist(aws_acm_certificate.main.domain_validation_options)[0].resource_record_type
}