# Note: Certificate and ALB must be in the same region.
resource "aws_acm_certificate" "main" {
  domain_name       = var.domain_name # e.g., www.xelta.ai
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-cert"
  }
}

# --- WAF for this region's ALB ---
resource "aws_wafv2_web_acl" "main" {
  name  = "${var.project_name}-waf"
  scope = "REGIONAL" # For use with ALB

  default_action {
    allow {}
  }

  rule {
    name     = "AWS-Managed-Core-Rule-Set"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-managed-rules"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf-metrics"
    sampled_requests_enabled   = true
  }
}

# --- CloudFront ---
resource "aws_cloudfront_distribution" "main" {
  origin {
    # This domain will be the ALB created by the k8s controller
    domain_name = "alb-origin-placeholder.${var.domain_name}"
    origin_id   = "alb-origin"
    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "http-only"
      origin_ssl_protocols     = ["TLSv1.2"]
    }
    custom_header {
      name  = "X-Custom-Header"
      value = "a-secure-value-to-be-replaced" # Replace with a secure value, e.g., from a secret manager
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  aliases             = [var.domain_name, "*.${var.domain_name}"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = true
      headers      = ["Host", "Authorization"]
      cookies {
        forward = "all"
      }
    }
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate_validation.main.certificate_arn
    ssl_support_method  = "sni-only"
  }
}

# --- Point DNS to CloudFront ---
resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.subdomain.zone_id
  name    = var.domain_name
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "wildcard" {
  zone_id = aws_route53_zone.subdomain.zone_id
  name    = "*.${var.domain_name}"
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}