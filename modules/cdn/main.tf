# Provider for us-east-1 for Lambda@Edge
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

data "archive_file" "edge_router" {
  type        = "zip"
  output_path = "${path.module}/edge_router.zip"
  source {
    content  = <<-EOT
      'use strict';

      exports.handler = (event, context, callback) => {
          const request = event.Records[0].cf.request;
          const headers = request.headers;

          // Define a mapping of continents/regions to AWS regions
          const regionMapping = {
              'EU': 'eu-central-1',
              'AS': 'ap-south-1',
              'NA': 'us-east-1',
              'SA': 'us-east-1',
              'OC': 'ap-south-1', // Oceania
              'AF': 'eu-central-1', // Africa
          };

          // A mapping of country codes to continents
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

          const newDomain = currentDomain.replace('us-east-1', targetRegion);

          request.origin.custom.domainName = newDomain;
          request.headers['host'] = [{ key: 'host', value: newDomain }];

          callback(null, request);
      };
    EOT
    filename = "index.js"
  }
}

resource "aws_iam_role" "lambda_edge" {
  name = "xelta-${var.environment}-lambda-edge-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "edgelambda.amazonaws.com"
          ]
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_edge_basic_execution" {
  role       = aws_iam_role.lambda_edge.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda@Edge function for intelligent routing
resource "aws_lambda_function" "edge_router" {
  provider         = aws.us_east_1  # Lambda@Edge must be in us-east-1
  filename         = data.archive_file.edge_router.output_path
  function_name    = "xelta-${var.environment}-edge-router"
  role             = aws_iam_role.lambda_edge.arn
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  publish          = true
  source_code_hash = data.archive_file.edge_router.output_base64sha256
}

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

    lambda_function_association {
      event_type   = "origin-request"
      lambda_arn   = aws_lambda_function.edge_router.qualified_arn
      include_body = false
    }
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
