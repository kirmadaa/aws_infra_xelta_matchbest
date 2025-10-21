# modules/cdn/main.tf

# --- START: Lambda@Edge for Geo-Routing (Unchanged) ---
resource "aws_iam_role" "lambda_edge" {
  name = "xelta-${var.environment}-lambda-edge-role"
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
  name = "xelta-${var.environment}-lambda-edge-logging"
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
data "archive_file" "lambda_edge_zip" {
  type = "zip"
  source {
    content = <<-EOT
'use strict';
exports.handler = (event, context, callback) => {
    const request = event.Records[0].cf.request;
    try {
        const headers = request.headers;
        const regionMapping = {
            'EU': 'eu-central-1', 'AS': 'ap-south-1', 'NA': 'us-east-1',
            'SA': 'us-east-1', 'OC': 'ap-south-1', 'AF': 'eu-central-1',
        };
        const countryToContinent = {
            'DE': 'EU', 'FR': 'EU', 'GB': 'EU', 'IT': 'EU', 'ES': 'EU', 'PL': 'EU', 'RO': 'EU', 'NL': 'EU', 'BE': 'EU', 'GR': 'EU', 'CZ': 'EU', 'PT': 'EU', 'SE': 'EU', 'HU': 'EU', 'AT': 'EU', 'CH': 'EU', 'BG': 'EU', 'DK': 'EU', 'FI': 'EU', 'SK': 'EU', 'IE': 'EU', 'HR': 'EU', 'LT': 'EU', 'SI': 'EU', 'LV': 'EU', 'EE': 'EU', 'CY': 'EU', 'LU': 'EU', 'MT': 'EU', 'IS': 'EU', 'NO': 'EU', 'RS': 'EU', 'BA': 'EU', 'MK': 'EU', 'AL': 'EU',
            'IN': 'AS', 'CN': 'AS', 'JP': 'AS', 'KR': 'AS', 'ID': 'AS', 'PK': 'AS', 'BD': 'AS', 'PH': 'AS', 'VN': 'AS', 'TR': 'AS', 'IR': 'AS', 'TH': 'AS', 'MM': 'AS', 'SA': 'AS', 'MY': 'AS', 'UZ': 'AS', 'IQ': 'AS', 'AF': 'AS', 'NP': 'AS', 'YE': 'AS', 'KZ': 'AS', 'KH': 'AS', 'JO': 'AS', 'AE': 'AS', 'IL': 'AS', 'HK': 'AS', 'LA': 'AS', 'SG': 'AS', 'OM': 'AS', 'KW': 'AS', 'QA': 'AS', 'BH': 'AS', 'MN': 'AS', 'TM': 'AS', 'GE': 'AS', 'AM': 'AS', 'AZ': 'AS',
            'US': 'NA', 'CA': 'NA', 'MX': 'NA',
            'BR': 'SA', 'CO': 'SA', 'AR': 'SA', 'PE': 'SA', 'VE': 'SA', 'CL': 'SA', 'EC': 'SA', 'BO': 'SA', 'PY': 'SA', 'UY': 'SA',
            'AU': 'OC', 'NZ': 'OC', 'PG': 'OC', 'FJ': 'OC',
            'NG': 'AF', 'ET': 'AF', 'EG': 'AF', 'CD': 'AF', 'TZ': 'AF', 'ZA': 'AF', 'KE': 'AF', 'UG': 'AF', 'DZ': 'AF', 'SD': 'AF', 'MA': 'AF', 'MZ': 'AF', 'GH': 'AF', 'AO': 'AF', 'CI': 'AF', 'CM': 'AF', 'NE': 'AF', 'ML': 'AF', 'MG': 'AF', 'ZM': 'AF', 'ZW': 'AF', 'SN': 'AF', 'TN': 'AF', 'GN': 'AF', 'RW': 'AF', 'BJ': 'AF', 'SO': 'AF', 'BI': 'AF', 'TG': 'AF', 'SL': 'AF', 'LR': 'AF', 'CF': 'AF', 'CG': 'AF', 'GA': 'AF', 'GW': 'AF', 'GQ': 'AF', 'SZ': 'AF', 'LS': 'AF', 'DJ': 'AF', 'KM': 'AF', 'SC': 'AF', 'CV': 'AF',
        };
        let targetRegion = 'us-east-1'; // Default region
        const currentDomain = request.origin.custom.domainName;
        if (headers['cloudfront-viewer-country']) {
            const countryCode = headers['cloudfront-viewer-country'][0].value;
            const continent = countryToContinent[countryCode];
            if (continent && regionMapping[continent]) {
                targetRegion = regionMapping[continent];
            }
        }
        if (targetRegion !== 'us-east-1') {
            const newDomain = currentDomain.replace('us-east-1', targetRegion);
            request.origin.custom.domainName = newDomain;
            request.headers['host'] = [{ key: 'host', value: newDomain }];
        }
        callback(null, request);
    } catch (e) {
        console.log('Error modifying edge request: ', e);
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
  function_name    = "xelta-${var.environment}-edge-router"
  role             = aws_iam_role.lambda_edge.arn
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  publish          = true
  depends_on       = [aws_iam_role_policy.lambda_edge_logs]
}
# --- END: Lambda@Edge for Geo-Routing ---


resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "xelta-${var.environment}"
  web_acl_id          = var.waf_web_acl_arn

  aliases = [var.domain_name]

  # Origins now point to the ALB DNS names
  dynamic "origin" {
    for_each = var.origins
    content {
      domain_name = origin.value # This is now the ALB DNS name
      origin_id   = origin.key

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "http-only" # ALB is internal, on port 80
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  # --- FIX: REMOVED ALL 'origin_group' BLOCKS ---
  # They are not used by the new architecture and were
  # causing the "Insufficient member blocks" error.

  # Default cache behavior
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "us-east-1" # Default, Lambda@Edge will override

    origin_request_policy_id = aws_cloudfront_origin_request_policy.default_alb.id
    cache_policy_id          = aws_cloudfront_cache_policy.api_caching.id
    
    viewer_protocol_policy   = "redirect-to-https"
    compress                 = true

    # Lambda@Edge association (unchanged)
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
    Name        = "xelta-${var.environment}-cdn"
    Environment = var.environment
  }
}

# --- This is the cache policy that enables caching for 60 seconds ---
resource "aws_cloudfront_cache_policy" "api_caching" {
  name    = "xelta-${var.environment}-api-caching-policy"
  comment = "Cache policy for API GET/HEAD requests"
  default_ttl = 60
  max_ttl     = 300
  min_ttl     = 0
  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "all"
    }
  }
}

# --- This is a default policy for ALBs ---
resource "aws_cloudfront_origin_request_policy" "default_alb" {
  name    = "xelta-${var.environment}-alb-policy"
  comment = "Forward Cookies and Query Strings"
  cookies_config {
    cookie_behavior = "all"
  }
  headers_config {
    header_behavior = "none"
  }
  query_strings_config {
    query_string_behavior = "all"
  }
}