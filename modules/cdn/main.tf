# modules/cdn/main.tf

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "xelta-${var.environment}"
  default_root_object = "index.html"
  web_acl_id          = var.waf_web_acl_arn

  aliases = [var.domain_name]

  dynamic "origin" {
    for_each = var.origins
    content {
      domain_name = replace(origin.value, "https://", "")
      origin_id   = origin.key

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  # Default cache behavior for API calls (no caching)
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "us-east-1" # Default to primary region

    forwarded_values {
      query_string = true
      headers      = ["*"] # Forward all headers for API requests
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0 # Do not cache API responses by default
    max_ttl                = 0
    compress               = true
  }

  # Cache behavior for static frontend assets (e.g., /static/*)
  ordered_cache_behavior {
    path_pattern     = "/static/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "us-east-1" # Serve static from primary region

    forwarded_values {
      query_string = false
      headers      = ["Origin"] # Forward only necessary headers
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400    # Cache for 1 day
    max_ttl                = 31536000 # Cache for 1 year
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name        = "xelta-${var.environment}-cdn"
    Environment = var.environment
  }
}