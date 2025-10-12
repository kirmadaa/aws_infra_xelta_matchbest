resource "aws_wafv2_web_acl" "main" {
  name        = "xelta-${var.environment}-waf-acl-${var.region}"
  scope       = "REGIONAL"
  default_action {
    allow {}
  }

  # Rule to block common SQL injection attacks
  rule {
    name     = "SQLiRule"
    priority = 1
    action {
      block {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesSQLiRuleSet"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "waf-sqli"
      sampled_requests_enabled   = true
    }
  }

  # Rule for Common Rule Set (blocks bad bots, exploits)
  rule {
    name     = "CommonRuleSet"
    priority = 2
    action {
      block {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "waf-common"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "waf-main"
    sampled_requests_enabled   = true
  }
}

# Associate WAF with the ALB
resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}
