# modules/cdn/main.tf

# --- Lambda@Edge IAM Role ---
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

# --- CORRECTED Lambda@Edge Function ---
data "archive_file" "lambda_edge_zip" {
  type = "zip"
  source {
    content = <<-EOT
'use strict';

exports.handler = (event, context, callback) => {
    const request = event.Records[0].cf.request;
    
    try {
        // Continent to region mapping (must match your origin IDs)
        const regionMapping = {
            'EU': 'eu-central-1',
            'AS': 'ap-south-1',
            'NA': 'us-east-1',
            'SA': 'us-east-1',
            'OC': 'ap-south-1',
            'AF': 'eu-central-1'
        };
        
        // Country to continent mapping
        const countryToContinent = {
            // Europe
            'DE': 'EU', 'FR': 'EU', 'GB': 'EU', 'IT': 'EU', 'ES': 'EU', 'PL': 'EU', 
            'RO': 'EU', 'NL': 'EU', 'BE': 'EU', 'GR': 'EU', 'CZ': 'EU', 'PT': 'EU',
            'SE': 'EU', 'HU': 'EU', 'AT': 'EU', 'CH': 'EU', 'BG': 'EU', 'DK': 'EU',
            'FI': 'EU', 'SK': 'EU', 'IE': 'EU', 'HR': 'EU', 'LT': 'EU', 'SI': 'EU',
            'LV': 'EU', 'EE': 'EU', 'CY': 'EU', 'LU': 'EU', 'MT': 'EU', 'IS': 'EU',
            'NO': 'EU', 'RS': 'EU', 'BA': 'EU', 'MK': 'EU', 'AL': 'EU', 'ME': 'EU',
            'XK': 'EU', 'MD': 'EU', 'UA': 'EU', 'BY': 'EU', 'RU': 'EU',
            
            // Asia
            'IN': 'AS', 'CN': 'AS', 'JP': 'AS', 'KR': 'AS', 'ID': 'AS', 'PK': 'AS',
            'BD': 'AS', 'PH': 'AS', 'VN': 'AS', 'TR': 'AS', 'IR': 'AS', 'TH': 'AS',
            'MM': 'AS', 'SA': 'AS', 'MY': 'AS', 'UZ': 'AS', 'IQ': 'AS', 'AF': 'AS',
            'NP': 'AS', 'YE': 'AS', 'KZ': 'AS', 'KH': 'AS', 'JO': 'AS', 'AE': 'AS',
            'IL': 'AS', 'HK': 'AS', 'LA': 'AS', 'SG': 'AS', 'OM': 'AS', 'KW': 'AS',
            'QA': 'AS', 'BH': 'AS', 'MN': 'AS', 'TM': 'AS', 'GE': 'AS', 'AM': 'AS',
            'AZ': 'AS', 'SY': 'AS', 'LB': 'AS', 'PS': 'AS', 'BT': 'AS', 'MV': 'AS',
            'LK': 'AS', 'TJ': 'AS', 'KG': 'AS', 'TW': 'AS', 'MO': 'AS', 'BN': 'AS',
            'TL': 'AS',
            
            // North America
            'US': 'NA', 'CA': 'NA', 'MX': 'NA', 'GT': 'NA', 'CU': 'NA', 'DO': 'NA',
            'HT': 'NA', 'HN': 'NA', 'NI': 'NA', 'CR': 'NA', 'PA': 'NA', 'BZ': 'NA',
            'SV': 'NA', 'JM': 'NA', 'TT': 'NA', 'BS': 'NA', 'BB': 'NA', 'LC': 'NA',
            'GD': 'NA', 'VC': 'NA', 'AG': 'NA', 'DM': 'NA', 'KN': 'NA',
            
            // South America
            'BR': 'SA', 'AR': 'SA', 'CO': 'SA', 'PE': 'SA', 'VE': 'SA', 'CL': 'SA',
            'EC': 'SA', 'BO': 'SA', 'PY': 'SA', 'UY': 'SA', 'GY': 'SA', 'SR': 'SA',
            'GF': 'SA',
            
            // Oceania
            'AU': 'OC', 'NZ': 'OC', 'PG': 'OC', 'FJ': 'OC', 'SB': 'OC', 'VU': 'OC',
            'NC': 'OC', 'PF': 'OC', 'WS': 'OC', 'KI': 'OC', 'FM': 'OC', 'TO': 'OC',
            'MH': 'OC', 'PW': 'OC', 'CK': 'OC', 'NU': 'OC', 'TK': 'OC', 'TV': 'OC',
            'NR': 'OC',
            
            // Africa
            'NG': 'AF', 'ET': 'AF', 'EG': 'AF', 'CD': 'AF', 'TZ': 'AF', 'ZA': 'AF',
            'KE': 'AF', 'UG': 'AF', 'DZ': 'AF', 'SD': 'AF', 'MA': 'AF', 'AO': 'AF',
            'MZ': 'AF', 'GH': 'AF', 'MG': 'AF', 'CM': 'AF', 'CI': 'AF', 'NE': 'AF',
            'BF': 'AF', 'ML': 'AF', 'MW': 'AF', 'ZM': 'AF', 'SN': 'AF', 'SO': 'AF',
            'TN': 'AF', 'SS': 'AF', 'TD': 'AF', 'LY': 'AF', 'LR': 'AF', 'SL': 'AF',
            'TG': 'AF', 'CF': 'AF', 'MR': 'AF', 'ER': 'AF', 'GM': 'AF', 'BW': 'AF',
            'GA': 'AF', 'LS': 'AF', 'GW': 'AF', 'GQ': 'AF', 'SZ': 'AF', 'DJ': 'AF',
            'RE': 'AF', 'KM': 'AF', 'CV': 'AF', 'SC': 'AF', 'ST': 'AF'
        };
        
        // Default to ap-south-1
        let targetOriginId = 'ap-south-1';
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
            timestamp: new Date().toISOString(),
            countryCode: countryCode,
            targetOriginId: targetOriginId,
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
  function_name    = "xelta-${var.environment}-edge-router"
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
  comment           = "xelta-${var.environment}"
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
    Name        = "xelta-${var.environment}-cdn"
    Environment = var.environment
  }
}

# Cache policy with CloudFront-Viewer-Country header
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
  name    = "xelta-${var.environment}-alb-policy"
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