# modules/cdn/main.tf

# --- Lambda@Edge IAM Role ---
resource "aws_iam_role" "lambda_edge" {
  name = "${var.app_name}-${var.environment}-lambda-edge-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
        }
      }
    ]
  })
  tags = {
    Name        = "xelta-${var.environment}-lambda-edge-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "lambda_edge_logs" {
  name = "${var.app_name}-${var.environment}-lambda-edge-logging"
  role = aws_iam_role.lambda_edge.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# --- CORRECTED Lambda@Edge Function ---
data "archive_file" "lambda_edge_zip" {
  type        = "zip"
  source {
    content = file("${path.module}/country-mapping.js")
    filename = "country-mapping.js"
  }
  source {
    content  = <<EOT
'use strict';

const { regionMapping, countryToContinent, defaultRegion } = require('./country-mapping');

exports.handler = async (event, context, callback) => {
    try {
        const request = event.Records[0].cf.request;
        
        // Default to ap-south-1
        let targetOriginId = defaultRegion;
        let countryCode = 'Unknown';
        
        // Get country from CloudFront headers
        if (request.headers['cloudfront-viewer-country']) {
            countryCode = request.headers['cloudfront-viewer-country'][0].value;
            const continent = countryToContinent[countryCode];
            
            if (continent && regionMapping[continent]) {
                targetOriginId = regionMapping[continent];
            }
        }
        
        // CRITICAL FIX: Modify the originId, do not replace the origin object.
        // This tells CloudFront which pre-configured origin to route to.
        request.origin.custom.originId = targetOriginId;

        // The Host header will be automatically set by CloudFront
        // to the domainName of the *chosen* origin (e.g., your-alb.us-east-1.elb.amazonaws.com)
        // No need to manually delete or set request.headers['host']

        console.log(JSON.stringify({
            message: 'Request routed',
            country: countryCode,
            targetOrigin: targetOriginId,
            originalUri: request.uri,
            userAgent: request.headers['user-agent'] ? request.headers['user-agent'][0].value : 'Unknown'
        }));
        
        callback(null, request);
        
    } catch (error) {
        console.error('Lambda@Edge Error:', {
            error: error.message,
            stack: error.stack
        });
        
        // On error, let it proceed to the default origin (ap-south-1)
        callback(null, request);
    }
};
EOT
    filename = "index.js"
  }
  output_path = "${path.module}/edge_router_payload.zip"
}

resource "aws_lambda_function" "edge_router" {
  filename         = data.archive_file.lambda_edge_zip.output_path
  source_code_hash = data.archive_file.lambda_edge_zip.output_base64sha256
  function_name    = "${var.app_name}-${var.environment}-edge-router"
  role             = aws_iam_role.lambda_edge.arn
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  publish          = true
  depends_on       = [aws_iam_role_policy.lambda_edge_logs]
}

# --- CloudFront Distribution ---
resource "aws_cloudfront_distribution" "main" {
  enabled           = true
  is_ipv6_enabled   = true
  comment           = "${var.app_name}-${var.environment}"
  web_acl_id        = var.waf_web_acl_arn

  aliases = [var.domain_name]

  # Origins - all 3 ALBs are defined
  dynamic "origin" {
    for_each = var.origins
    content {
      domain_name = origin.value
      origin_id   = origin.key # e.g., "us-east-1", "eu-central-1"

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "http-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  # Default cache behavior with CORRECTED Lambda@Edge
  default_cache_behavior {
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]
    
    # This is just the default; the Lambda will override it
    target_origin_id = "ap-south-1" 

    origin_request_policy_id = aws_cloudfront_origin_request_policy.default_alb.id
    cache_policy_id          = aws_cloudfront_cache_policy.api_caching.id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    # CRITICAL CHANGE: "viewer-request" event type
    lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = aws_lambda_function.edge_router.qualified_arn
      include_body = false
    }
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
    Name        = "${var.app_name}-${var.environment}-cdn"
    Environment = var.environment
  }
}

# Cache policy with CloudFront-Viewer-Country header
resource "aws_cloudfront_cache_policy" "api_caching" {
  name    = "${var.app_name}-${var.environment}-api-caching-policy"
  comment = "Cache policy for API GET/HEAD requests"
  default_ttl = 60
  max_ttl     = 300
  min_ttl     = 0
  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "whitelist"
      headers {
        # This is required so the Lambda@Edge has the header to inspect
        items = ["CloudFront-Viewer-Country"] 
      }
    }
    query_strings_config {
      query_string_behavior = "all"
    }
  }
}

# Origin request policy for ALBs
resource "aws_cloudfront_origin_request_policy" "default_alb" {
  name    = "${var.app_name}-${var.environment}-alb-policy"
  comment = "Forward Cookies, Query Strings and necessary headers"
  cookies_config {
    cookie_behavior = "all"
  }
  headers_config {
    header_behavior = "whitelist"
    headers {
      items = [
        # Forward the country header to the origin ALB
        "CloudFront-Viewer-Country", 
        "User-Agent", 
        "Accept", 
        "Accept-Language",
        # "Accept-Encoding", # <-- Correctly commented out
        "Content-Type"
      ]
    }
  }
  query_strings_config {
    query_string_behavior = "all"
  }
}