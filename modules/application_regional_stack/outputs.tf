output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = module.route53_acm.certificate_arn
}
