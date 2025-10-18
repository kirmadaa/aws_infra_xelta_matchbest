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

# WAF & CDN (Global resources)
module "waf" {
  source      = "./modules/waf"
  environment = var.environment
}

module "cdn" {
  source      = "./modules/cdn"
  environment = var.environment
  domain_name = var.domain_name
  route53_zone_id = data.aws_route53_zone.main.zone_id
  waf_web_acl_arn = module.waf.waf_arn

  # Origin info for each regional API Gateway
  origins = {
    us-east-1    = module.api_gateway_us_east_1.api_endpoint
    eu-central-1 = module.api_gateway_eu_central_1.api_endpoint
    ap-south-1   = module.api_gateway_ap_south_1.api_endpoint
  }

  # ACM certificate for the CDN (must be in us-east-1)
  certificate_arn = module.route53_acm_us_east_1.certificate_arn
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
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  single_nat_gateway = var.environment == "dev" ? true : false
}

module "ecs_service_us_east_1" {
  source    = "./modules/ecs_service"
  providers = { aws = aws.us_east_1 }

  environment         = var.environment
  region              = "us-east-1"
  vpc_id              = module.vpc_us_east_1.vpc_id
  vpc_cidr            = var.vpc_cidr_blocks["us-east-1"]
  private_subnet_ids  = module.vpc_us_east_1.private_subnet_ids
  frontend_image      = var.frontend_image
  backend_image       = var.backend_image
}

module "api_gateway_us_east_1" {
  source    = "./modules/api_gateway"
  providers = { aws = aws.us_east_1 }

  environment                   = var.environment
  region                        = "us-east-1"
  vpc_id                        = module.vpc_us_east_1.vpc_id
  private_subnet_ids            = module.vpc_us_east_1.private_subnet_ids
  ecs_service_security_group_id = module.ecs_service_us_east_1.service_security_group_id
  ecs_service_arn               = module.ecs_service_us_east_1.backend_service_arn  # <-- CORRECTED
  nlb_listener_arn              = module.ecs_service_us_east_1.backend_nlb_listener_arn # <-- CORRECTED
}

module "route53_acm_us_east_1" {
  source    = "./modules/route53_acm"
  providers = { aws = aws.us_east_1 }

  environment     = var.environment
  region          = "us-east-1"
  domain_name     = var.domain_name
  route53_zone_id = data.aws_route53_zone.main.zone_id

  # Create Route53 record for the CDN
  cdn_dns_name    = module.cdn.cdn_dns_name
  cdn_zone_id     = module.cdn.cdn_zone_id
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

  allowed_security_group_ids = [module.ecs_service_us_east_1.service_security_group_id]
}

module "websocket_api_gateway_us_east_1" {
  count     = var.enable_websocket_api ? 1 : 0
  source    = "./modules/websocket_api_gateway"
  providers = { aws = aws.us_east_1 }

  environment      = var.environment
  region           = "us-east-1"
  vpc_id           = module.vpc_us_east_1.vpc_id
  nlb_arn          = module.ecs_service_us_east_1.nlb_arn
  nlb_listener_arn = module.ecs_service_us_east_1.backend_nlb_listener_arn # Assuming WebSocket API is for the backend
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

module "ecs_service_eu_central_1" {
  source    = "./modules/ecs_service"
  providers = { aws = aws.eu_central_1 }

  environment         = var.environment
  region              = "eu-central-1"
  vpc_id              = module.vpc_eu_central_1.vpc_id
  vpc_cidr            = var.vpc_cidr_blocks["eu-central-1"]
  private_subnet_ids  = module.vpc_eu_central_1.private_subnet_ids
  frontend_image      = var.frontend_image
  backend_image       = var.backend_image
}

module "api_gateway_eu_central_1" {
  source    = "./modules/api_gateway"
  providers = { aws = aws.eu_central_1 }

  environment                   = var.environment
  region                        = "eu-central-1"
  vpc_id                        = module.vpc_eu_central_1.vpc_id
  private_subnet_ids            = module.vpc_eu_central_1.private_subnet_ids
  ecs_service_security_group_id = module.ecs_service_eu_central_1.service_security_group_id
  ecs_service_arn               = module.ecs_service_eu_central_1.backend_service_arn  # <-- CORRECTED
  nlb_listener_arn              = module.ecs_service_eu_central_1.backend_nlb_listener_arn # <-- CORRECTED
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

  allowed_security_group_ids = [module.ecs_service_eu_central_1.service_security_group_id]
}

module "websocket_api_gateway_eu_central_1" {
  count     = var.enable_websocket_api ? 1 : 0
  source    = "./modules/websocket_api_gateway"
  providers = { aws = aws.eu_central_1 }

  environment      = var.environment
  region           = "eu-central-1"
  vpc_id           = module.vpc_eu_central_1.vpc_id
  nlb_arn          = module.ecs_service_eu_central_1.nlb_arn
  nlb_listener_arn = module.ecs_service_eu_central_1.backend_nlb_listener_arn
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

module "ecs_service_ap_south_1" {
  source    = "./modules/ecs_service"
  providers = { aws = aws.ap_south_1 }

  environment         = var.environment
  region              = "ap-south-1"
  vpc_id              = module.vpc_ap_south_1.vpc_id
  vpc_cidr            = var.vpc_cidr_blocks["ap-south-1"]
  private_subnet_ids  = module.vpc_ap_south_1.private_subnet_ids
  frontend_image      = var.frontend_image
  backend_image       = var.backend_image
}

module "api_gateway_ap_south_1" {
  source    = "./modules/api_gateway"
  providers = { aws = aws.ap_south_1 }

  environment                   = var.environment
  region                        = "ap-south-1"
  vpc_id                        = module.vpc_ap_south_1.vpc_id
  private_subnet_ids            = module.vpc_ap_south_1.private_subnet_ids
  ecs_service_security_group_id = module.ecs_service_ap_south_1.service_security_group_id
  ecs_service_arn               = module.ecs_service_ap_south_1.backend_service_arn  # <-- CORRECTED
  nlb_listener_arn              = module.ecs_service_ap_south_1.backend_nlb_listener_arn # <-- CORRECTED
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

  allowed_security_group_ids = [module.ecs_service_ap_south_1.service_security_group_id]
}

module "websocket_api_gateway_ap_south_1" {
  count     = var.enable_websocket_api ? 1 : 0
  source    = "./modules/websocket_api_gateway"
  providers = { aws = aws.ap_south_1 }

  environment      = var.environment
  region           = "ap-south-1"
  vpc_id           = module.vpc_ap_south_1.vpc_id
  nlb_arn          = module.ecs_service_ap_south_1.nlb_arn
  nlb_listener_arn = module.ecs_service_ap_south_1.backend_nlb_listener_arn
}
