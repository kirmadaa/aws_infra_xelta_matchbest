output "certificate_arn" {
  description = "ACM certificate ARN"
  value       = aws_acm_certificate.main.arn
}

output "route53_record_name" {
  description = "Route53 record name"
  value       = aws_route53_record.app.name
}

output "route53_record_fqdn" {
  description = "Route53 record FQDN"
  value       = aws_route53_record.app.fqdn
}

