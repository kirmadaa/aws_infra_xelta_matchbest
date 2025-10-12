# Data source for Route53 hosted zone
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}


# Global secrets (stored in us-east-1, replicated to other regions)
module "secrets_us_east_1" {
  source    = "./modules/secrets"
  providers = { aws = aws.us_east_1 }

  environment = var.environment
}

module "secrets_eu_central_1" {
  source    = "./modules/secrets"
  providers = { aws = aws.eu_central_1 }

  environment = var.environment
}

module "secrets_ap_south_1" {
  source    = "./modules/secrets"
  providers = { aws = aws.ap_south_1 }

  environment = var.environment
}

# ===========================
# US-EAST-1 REGION RESOURCES
# ===========================
module "vpc_us_east_1" {
  source    = "./modules/vpc"
  providers = { aws = aws.us_east_1 }

  environment        = var.environment
  region             = "us-east-1"
  vpc_cidr           = var.vpc_cidr_blocks["us-east-1"]
  # 3 AZs for high availability
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  single_nat_gateway = var.environment == "dev" ? true : false
}

module "alb_us_east_1" {
  source    = "./modules/alb_ingress"
  providers = { aws = aws.us_east_1 }

  environment       = var.environment
  region            = "us-east-1"
  vpc_id            = module.vpc_us_east_1.vpc_id
  public_subnet_ids = module.vpc_us_east_1.public_subnet_ids
  certificate_arn   = module.route53_acm_us_east_1.certificate_arn

  # Create two target groups
  target_groups = {
    frontend = {
      port              = 3000
      protocol          = "HTTP"
      health_check_path = "/"
    },
    backend = {
      port              = 8080
      protocol          = "HTTP"
      health_check_path = "/health"
    }
  }

  # Add listener rules to route traffic
  listener_rules = {
    backend = {
      priority         = 100
      path_patterns    = ["/api/*"]
      target_group_key = "backend"
    }
  }
}

module "ecs_frontend_us_east_1" {
  source    = "./modules/ecs"
  providers = { aws = aws.us_east_1 }

  service_name         = "frontend"
  container_image      = "your-account-id.dkr.ecr.us-east-1.amazonaws.com/frontend:latest"
  container_port       = 3000
  environment          = var.environment
  region               = "us-east-1"
  vpc_id               = module.vpc_us_east_1.vpc_id
  private_subnet_ids   = module.vpc_us_east_1.private_subnet_ids
  alb_target_group_arn = module.alb_us_east_1.target_group_arns["frontend"]
}

module "ecs_backend_us_east_1" {
  source    = "./modules/ecs"
  providers = { aws = aws.us_east_1 }

  service_name         = "backend"
  container_image      = "your-account-id.dkr.ecr.us-east-1.amazonaws.com/backend:latest"
  container_port       = 8080
  environment          = var.environment
  region               = "us-east-1"
  vpc_id               = module.vpc_us_east_1.vpc_id
  private_subnet_ids   = module.vpc_us_east_1.private_subnet_ids
  alb_target_group_arn = module.alb_us_east_1.target_group_arns["backend"]
}

module "waf_us_east_1" {
  source    = "./modules/waf"
  providers = { aws = aws.us_east_1 }

  environment = var.environment
  region      = "us-east-1"
  alb_arn     = module.alb_us_east_1.alb_arn
}

module "route53_acm_us_east_1" {
  source    = "./modules/route53_acm"
  providers = { aws = aws.us_east_1 }

  environment     = var.environment
  region          = "us-east-1"
  domain_name     = var.domain_name
  route53_zone_id = data.aws_route53_zone.main.zone_id

  alb_dns_name    = module.alb_us_east_1.alb_dns_name
  alb_zone_id     = module.alb_us_east_1.alb_zone_id
}

module "redis_us_east_1" {
  count     = var.enable_redis ? 1 : 0
  source    = "./modules/elasticache_redis"
  providers = { aws = aws.us_east_1 }

  environment      = var.environment
  region           = "us-east-1"
  vpc_id           = module.vpc_us_east_1.vpc_id
  private_subnet_ids = module.vpc_us_east_1.private_subnet_ids

  node_type       = var.redis_node_type
  num_cache_nodes = var.redis_num_cache_nodes

  allowed_security_group_ids = [
    module.ecs_frontend_us_east_1.service_security_group_id,
    module.ecs_backend_us_east_1.service_security_group_id
  ]
}

module "aurora_us_east_1" {
  count     = var.enable_aurora ? 1 : 0
  source    = "./modules/rds_aurora"
  providers = { aws = aws.us_east_1 }

  environment        = var.environment
  region             = "us-east-1"
  vpc_id             = module.vpc_us_east_1.vpc_id
  private_subnet_ids = module.vpc_us_east_1.private_subnet_ids

  instance_class = var.aurora_instance_class
  instance_count = var.aurora_instance_count
  db_secret_arn  = module.secrets_us_east_1.db_secret_arn

  allowed_security_group_ids = [
    module.ecs_frontend_us_east_1.service_security_group_id,
    module.ecs_backend_us_east_1.service_security_group_id
  ]
}

# ===============================
# EU-CENTRAL-1 REGION RESOURCES
# ===============================
module "vpc_eu_central_1" {
  source    = "./modules/vpc"
  providers = { aws = aws.eu_central_1 }

  environment        = var.environment
  region             = "eu-central-1"
  vpc_cidr           = var.vpc_cidr_blocks["eu-central-1"]
  availability_zones = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  single_nat_gateway = var.environment == "dev" ? true : false
}

module "alb_eu_central_1" {
  source    = "./modules/alb_ingress"
  providers = { aws = aws.eu_central_1 }

  environment       = var.environment
  region            = "eu-central-1"
  vpc_id            = module.vpc_eu_central_1.vpc_id
  public_subnet_ids = module.vpc_eu_central_1.public_subnet_ids
  certificate_arn   = module.route53_acm_eu_central_1.certificate_arn

  target_groups = {
    frontend = {
      port              = 3000
      protocol          = "HTTP"
      health_check_path = "/"
    },
    backend = {
      port              = 8080
      protocol          = "HTTP"
      health_check_path = "/health"
    }
  }

  listener_rules = {
    backend = {
      priority         = 100
      path_patterns    = ["/api/*"]
      target_group_key = "backend"
    }
  }
}

module "ecs_frontend_eu_central_1" {
  source    = "./modules/ecs"
  providers = { aws = aws.eu_central_1 }

  service_name         = "frontend"
  container_image      = "your-account-id.dkr.ecr.eu-central-1.amazonaws.com/frontend:latest"
  container_port       = 3000
  environment          = var.environment
  region               = "eu-central-1"
  vpc_id               = module.vpc_eu_central_1.vpc_id
  private_subnet_ids   = module.vpc_eu_central_1.private_subnet_ids
  alb_target_group_arn = module.alb_eu_central_1.target_group_arns["frontend"]
}

module "ecs_backend_eu_central_1" {
  source    = "./modules/ecs"
  providers = { aws = aws.eu_central_1 }

  service_name         = "backend"
  container_image      = "your-account-id.dkr.ecr.eu-central-1.amazonaws.com/backend:latest"
  container_port       = 8080
  environment          = var.environment
  region               = "eu-central-1"
  vpc_id               = module.vpc_eu_central_1.vpc_id
  private_subnet_ids   = module.vpc_eu_central_1.private_subnet_ids
  alb_target_group_arn = module.alb_eu_central_1.target_group_arns["backend"]
}

module "waf_eu_central_1" {
  source    = "./modules/waf"
  providers = { aws = aws.eu_central_1 }

  environment = var.environment
  region      = "eu-central-1"
  alb_arn     = module.alb_eu_central_1.alb_arn
}

module "route53_acm_eu_central_1" {
  source    = "./modules/route53_acm"
  providers = { aws = aws.eu_central_1 }

  environment     = var.environment
  region          = "eu-central-1"
  domain_name     = var.domain_name
  route53_zone_id = data.aws_route53_zone.main.zone_id

  alb_dns_name    = module.alb_eu_central_1.alb_dns_name
  alb_zone_id     = module.alb_eu_central_1.alb_zone_id
}

module "redis_eu_central_1" {
  count     = var.enable_redis ? 1 : 0
  source    = "./modules/elasticache_redis"
  providers = { aws = aws.eu_central_1 }

  environment      = var.environment
  region           = "eu-central-1"
  vpc_id           = module.vpc_eu_central_1.vpc_id
  private_subnet_ids = module.vpc_eu_central_1.private_subnet_ids

  node_type       = var.redis_node_type
  num_cache_nodes = var.redis_num_cache_nodes

  allowed_security_group_ids = [
    module.ecs_frontend_eu_central_1.service_security_group_id,
    module.ecs_backend_eu_central_1.service_security_group_id
  ]
}

module "aurora_eu_central_1" {
  count     = var.enable_aurora ? 1 : 0
  source    = "./modules/rds_aurora"
  providers = { aws = aws.eu_central_1 }

  environment        = var.environment
  region             = "eu-central-1"
  vpc_id             = module.vpc_eu_central_1.vpc_id
  private_subnet_ids = module.vpc_eu_central_1.private_subnet_ids

  instance_class = var.aurora_instance_class
  instance_count = var.aurora_instance_count
  db_secret_arn  = module.secrets_eu_central_1.db_secret_arn

  allowed_security_group_ids = [
    module.ecs_frontend_eu_central_1.service_security_group_id,
    module.ecs_backend_eu_central_1.service_security_group_id
  ]
}

# ============================
# AP-SOUTH-1 REGION RESOURCES
# ============================
module "vpc_ap_south_1" {
  source    = "./modules/vpc"
  providers = { aws = aws.ap_south_1 }

  environment        = var.environment
  region             = "ap-south-1"
  vpc_cidr           = var.vpc_cidr_blocks["ap-south-1"]
  availability_zones = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
  single_nat_gateway = var.environment == "dev" ? true : false
}

module "alb_ap_south_1" {
  source    = "./modules/alb_ingress"
  providers = { aws = aws.ap_south_1 }

  environment       = var.environment
  region            = "ap-south-1"
  vpc_id            = module.vpc_ap_south_1.vpc_id
  public_subnet_ids = module.vpc_ap_south_1.public_subnet_ids
  certificate_arn   = module.route53_acm_ap_south_1.certificate_arn

  target_groups = {
    frontend = {
      port              = 3000
      protocol          = "HTTP"
      health_check_path = "/"
    },
    backend = {
      port              = 8080
      protocol          = "HTTP"
      health_check_path = "/health"
    }
  }

  listener_rules = {
    backend = {
      priority         = 100
      path_patterns    = ["/api/*"]
      target_group_key = "backend"
    }
  }
}

module "ecs_frontend_ap_south_1" {
  source    = "./modules/ecs"
  providers = { aws = aws.ap_south_1 }

  service_name         = "frontend"
  container_image      = "your-account-id.dkr.ecr.ap-south-1.amazonaws.com/frontend:latest"
  container_port       = 3000
  environment          = var.environment
  region               = "ap-south-1"
  vpc_id               = module.vpc_ap_south_1.vpc_id
  private_subnet_ids   = module.vpc_ap_south_1.private_subnet_ids
  alb_target_group_arn = module.alb_ap_south_1.target_group_arns["frontend"]
}

module "ecs_backend_ap_south_1" {
  source    = "./modules/ecs"
  providers = { aws = aws.ap_south_1 }

  service_name         = "backend"
  container_image      = "your-account-id.dkr.ecr.ap-south-1.amazonaws.com/backend:latest"
  container_port       = 8080
  environment          = var.environment
  region               = "ap-south-1"
  vpc_id               = module.vpc_ap_south_1.vpc_id
  private_subnet_ids   = module.vpc_ap_south_1.private_subnet_ids
  alb_target_group_arn = module.alb_ap_south_1.target_group_arns["backend"]
}

module "waf_ap_south_1" {
  source    = "./modules/waf"
  providers = { aws = aws.ap_south_1 }

  environment = var.environment
  region      = "ap-south-1"
  alb_arn     = module.alb_ap_south_1.alb_arn
}

module "route53_acm_ap_south_1" {
  source    = "./modules/route53_acm"
  providers = { aws = aws.ap_south_1 }

  environment     = var.environment
  region          = "ap-south-1"
  domain_name     = var.domain_name
  route53_zone_id = data.aws_route53_zone.main.zone_id

  alb_dns_name    = module.alb_ap_south_1.alb_dns_name
  alb_zone_id     = module.alb_ap_south_1.alb_zone_id
}

module "redis_ap_south_1" {
  count     = var.enable_redis ? 1 : 0
  source    = "./modules/elasticache_redis"
  providers = { aws = aws.ap_south_1 }

  environment      = var.environment
  region           = "ap-south-1"
  vpc_id           = module.vpc_ap_south_1.vpc_id
  private_subnet_ids = module.vpc_ap_south_1.private_subnet_ids

  node_type       = var.redis_node_type
  num_cache_nodes = var.redis_num_cache_nodes

  allowed_security_group_ids = [
    module.ecs_frontend_ap_south_1.service_security_group_id,
    module.ecs_backend_ap_south_1.service_security_group_id
  ]
}

# ============================
# GLOBAL RESOURCES (CLOUDFRONT)
# ============================

# Provider for global resources that must be in us-east-1
provider "aws" {
  alias  = "us-east-1-global"
  region = "us-east-1"
}

resource "aws_cloudfront_distribution" "cdn" {
  provider = aws.us-east-1-global

  origin {
    domain_name = module.alb_us_east_1.alb_dns_name
    origin_id   = "alb-us-east-1"
    # Custom origin config for ALB
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin {
    domain_name = module.alb_eu_central_1.alb_dns_name
    origin_id   = "alb-eu-central-1"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin {
    domain_name = module.alb_ap_south_1.alb_dns_name
    origin_id   = "alb-ap-south-1"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CDN for xelta.ai"
  default_root_object = "index.html"

  aliases = [var.domain_name, "www.${var.domain_name}"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "alb-us-east-1" # Default origin

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # API cache behavior - forward all headers and do not cache
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "alb-us-east-1" # This will be overwritten by origin groups when we set up latency-based routing in Route 53

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
    max_ttl                = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = module.route53_acm_us_east_1.certificate_arn # Must be in us-east-1
    ssl_support_method  = "sni-only"
  }
}

module "aurora_ap_south_1" {
  count     = var.enable_aurora ? 1 : 0
  source    = "./modules/rds_aurora"
  providers = { aws = aws.ap_south_1 }

  environment        = var.environment
  region             = "ap-south-1"
  vpc_id             = module.vpc_ap_south_1.vpc_id
  private_subnet_ids = module.vpc_ap_south_1.private_subnet_ids

  instance_class = var.aurora_instance_class
  instance_count = var.aurora_instance_count
  db_secret_arn  = module.secrets_ap_south_1.db_secret_arn

  allowed_security_group_ids = [
    module.ecs_frontend_ap_south_1.service_security_group_id,
    module.ecs_backend_ap_south_1.service_security_group_id
  ]
}