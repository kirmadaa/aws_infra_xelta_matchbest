# modules/cdn/main.tf
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "xelta-${var.environment}"
  default_root_object = "index.html"
  web_acl_id          = var.waf_web_acl_arn
  price_class         = "PriceClass_All"

  aliases = [var.domain_name]

  # FIXED: Properly configured origins for API Gateway
  dynamic "origin" {
    for_each = var.origins
    content {
      domain_name = replace(replace(origin.value, "https://", ""), "http://", "")
      origin_id   = origin.key

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }

      custom_header {
        name  = "X-Custom-Header"
        value = "xelta-${var.environment}"
      }
    }
  }

  origin_group {
    origin_id = "group-us-east-1"
    failover_criteria {
      status_codes = [403, 404, 500, 502, 503, 504]
    }
    member {
      origin_id = "us-east-1"
    }
    member {
      origin_id = "eu-central-1"
    }
  }

  origin_group {
    origin_id = "group-eu-central-1"
    failover_criteria {
      status_codes = [403, 404, 500, 502, 503, 504]
    }
    member {
      origin_id = "eu-central-1"
    }
    member {
      origin_id = "us-east-1"
    }
  }

  origin_group {
    origin_id = "group-ap-south-1"
    failover_criteria {
      status_codes = [403, 404, 500, 502, 503, 504]
    }
    member {
      origin_id = "ap-south-1"
    }
    member {
      origin_id = "us-east-1"
    }
  }

  # FIXED: Use single origins instead of origin groups for write methods
  # Route to primary region (us-east-1) for all requests
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "us-east-1"  # Direct to origin, not origin group

    forwarded_values {
      query_string = true
      headers      = ["*"]  # Forward all headers for API requests
      
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0      # Don't cache by default for API
    max_ttl                = 86400
    compress               = true
  }

  # Enhanced cache behaviors for static assets
  ordered_cache_behavior {
    path_pattern     = "/_next/static/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "us-east-1"

    forwarded_values {
      query_string = false
      headers      = ["CloudFront-Viewer-Country"]
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 31536000  # 1 year
    default_ttl            = 31536000
    max_ttl                = 31536000
    compress               = true
  }

  # EU region routing - direct to origin
  ordered_cache_behavior {
    path_pattern     = "/eu/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "eu-central-1"  # Direct to origin, not origin group

    forwarded_values {
      query_string = true
      headers      = ["*"]
      
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 86400
    compress               = true
  }

  # AP region routing - direct to origin
  ordered_cache_behavior {
    path_pattern     = "/ap/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "ap-south-1"  # Direct to origin, not origin group

    forwarded_values {
      query_string = true
      headers      = ["*"]
      
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 86400
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
