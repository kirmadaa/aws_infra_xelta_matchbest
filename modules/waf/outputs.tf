output "waf_arn" {
  description = "The ARN of the WAF"
  value       = aws_wafv2_web_acl.main.arn
}
