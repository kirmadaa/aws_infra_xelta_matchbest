# modules/cdn/main.tf

# --- NEW DATA SOURCE ---
# We add this data source to find the ID of the AWS-managed policy
# that disables all caching, which is correct for an API.
data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}
# --- END NEW DATA SOURCE ---

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "xelta-${var.environment}"
  #default_root_object = "index.html"
  web_acl_id          = var.waf_web_acl_arn

  aliases = [var.domain_name]

  # FIXED: Properly configured origins for API Gateway
  dynamic "origin" {
    for_each = var.origins
    content {
      domain_name = replace(replace(origin.value, "https://", ""), "http://", "")
      origin_id   = origin.key
      # We removed origin_path = "/$default" because it's incorrect for an HTTP API

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
    target_origin_id = "us-east-1" # Direct to origin, not origin group

    # --- START OF FIX ---
    # We are commenting out the old 'forwarded_values' block
    # forwarded_values {
    #   query_string = true
    #   # headers      = ["*"]  # Forward all headers for API requests
    #   
    #   cookies {
    #     forward = "all"
    #   }
    # }

    # And replacing it with the new Origin Request Policy
    origin_request_policy_id = aws_cloudfront_origin_request_policy.api_gateway_policy.id

    # We MUST add a cache policy when using an origin request policy.
    # We will use the AWS-managed "CachingDisabled" policy.
    cache_policy_id = data.aws_cloudfront_cache_policy.caching_disabled.id
    # --- END OF FIX ---

    viewer_protocol_policy = "redirect-to-https"

    # --- FIX: We comment these out because they are now controlled by the Cache Policy ---
    # min_ttl                = 0
    # default_ttl            = 0 # Don't cache by default for API
    # max_ttl                = 86400
    # --- END FIX ---
    
    compress               = true
  }

  # EU region routing - direct to origin
  ordered_cache_behavior {
    path_pattern     = "/eu/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "eu-central-1" # Direct to origin, not origin group

    # --- START OF FIX ---
    # We are commenting out the old 'forwarded_values' block
    # forwarded_values {
    #   query_string = true
    #   # headers      = ["*"]
    #   
    #   cookies {
    #     forward = "all"
    #   }
    # }

    # And replacing it with the new Origin Request Policy
    origin_request_policy_id = aws_cloudfront_origin_request_policy.api_gateway_policy.id

    # We MUST add a cache policy when using an origin request policy.
    cache_policy_id = data.aws_cloudfront_cache_policy.caching_disabled.id
    # --- END OF FIX ---

    viewer_protocol_policy = "redirect-to-https"
    
    # --- FIX: We comment these out because they are now controlled by the Cache Policy ---
    # min_ttl                = 0
    # default_ttl            = 0
    # max_ttl                = 86400
    # --- END FIX ---
    
    compress               = true
  }

  # AP region routing - direct to origin
  ordered_cache_behavior {
    path_pattern     = "/ap/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "ap-south-1" # Direct to origin, not origin group

    # --- START OF FIX ---
    # We are commenting out the old 'forwarded_values' block
    # forwarded_values {
    #   query_string = true
    # #  headers      = ["*"]
    #   
    #   cookies {
    #     forward = "all"
    #   }
    # }

    # And replacing it with the new Origin Request Policy
    origin_request_policy_id = aws_cloudfront_origin_request_policy.api_gateway_policy.id

    # We MUST add a cache policy when using an origin request policy.
    cache_policy_id = data.aws_cloudfront_cache_policy.caching_disabled.id
    # --- END OF FIX ---

    viewer_protocol_policy = "redirect-to-https"
    
    # --- FIX: We comment these out because they are now controlled by the Cache Policy ---
    # min_ttl                = 0
    # default_ttl            = 0
    # max_ttl                = 86400
    # --- END FIX ---
    
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

# --- This resource is correct and stays ---

# This policy will forward all cookies and query strings, but NO headers.
# This forces CloudFront to send the correct 'Host' header to API Gateway.
resource "aws_cloudfront_origin_request_policy" "api_gateway_policy" {
  name    = "xelta-${var.environment}-api-gateway-policy"
  comment = "Forward Cookies and Query Strings, but not Host header"

  cookies_config {
    cookie_behavior = "all"
  }

  headers_config {
    # By setting this to "none", we prevent the user's "Host" header
    # from being forwarded, which fixes the "Forbidden" error.
    header_behavior = "none"
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}