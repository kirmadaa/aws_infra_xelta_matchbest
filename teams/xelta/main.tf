# Data source for Route53 hosted zone
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# ==========================================
# SHARED INFRASTRUCTURE (VPC, ALB, NLB)
# ==========================================

module "shared_us_east_1" {
  source = "../../modules/shared_regional_stack"
  providers = { aws = aws.us_east_1 }

  environment             = var.environment
  region                  = "us-east-1"
  vpc_cidr                = var.vpc_cidr_blocks["us-east-1"]
  availability_zones      = ["us-east-1a", "us-east-1b", "us-east-1c"]
  single_nat_gateway      = var.environment == "dev" ? true : false
  enable_ec2_nat_instance = var.enable_ec2_nat_instance
}

module "shared_eu_central_1" {
  source = "../../modules/shared_regional_stack"
  providers = { aws = aws.eu_central_1 }

  environment             = var.environment
  region                  = "eu-central-1"
  vpc_cidr                = var.vpc_cidr_blocks["eu-central-1"]
  availability_zones      = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  single_nat_gateway      = var.environment == "dev" ? true : false
  enable_ec2_nat_instance = var.enable_ec2_nat_instance
}

module "shared_ap_south_1" {
  source = "../../modules/shared_regional_stack"
  providers = { aws = aws.ap_south_1 }

  environment             = var.environment
  region                  = "ap-south-1"
  vpc_cidr                = var.vpc_cidr_blocks["ap-south-1"]
  availability_zones      = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
  single_nat_gateway      = var.environment == "dev" ? true : false
  enable_ec2_nat_instance = var.enable_ec2_nat_instance
}

# ==========================================
# APPLICATION STACK (Xelta)
# ==========================================

# --- US-EAST-1 Stack ---
module "us_east_1_stack" {
  source = "../../modules/application_regional_stack"
  count  = var.enable_infrastructure ? 1 : 0
  providers = {
    aws = aws.us_east_1
  }

  app_name                  = "xelta"
  environment               = var.environment
  region                    = "us-east-1"
  
  # Shared Infra Inputs
  vpc_id                      = module.shared_us_east_1.vpc_id
  private_subnet_ids          = module.shared_us_east_1.private_subnet_ids
  frontend_alb_listener_arn   = module.shared_us_east_1.frontend_alb_listener_arn
  alb_security_group_id       = module.shared_us_east_1.alb_security_group_id
  
  # App Specific Inputs
  frontend_image            = var.frontend_images["us-east-1"]
  backend_image             = var.backend_images["us-east-1"]
  domain_name               = var.domain_name
  route53_zone_id           = data.aws_route53_zone.main.zone_id
  cdn_dns_name              = try(module.cdn[0].cdn_dns_name, "")
  cdn_zone_id               = try(module.cdn[0].cdn_zone_id, "")
  enable_redis              = var.enable_redis
  redis_node_type           = var.redis_node_type
  redis_num_cache_nodes     = var.redis_num_cache_nodes
  enable_websocket_api      = var.enable_websocket_api
  api_gateway_cors_origins  = var.api_gateway_cors_origins
  api_gateway_cors_methods  = var.api_gateway_cors_methods
  api_gateway_cors_headers  = var.api_gateway_cors_headers
  lambda_connect_zip_path   = "${path.module}/lambda/connect.zip"
  lambda_start_job_zip_path = "${path.module}/lambda/start_job.zip"
  lambda_worker_zip_path    = "${path.module}/lambda/worker.zip"
}

# --- EU-CENTRAL-1 Stack ---
module "eu_central_1_stack" {
  source = "../../modules/application_regional_stack"
  count  = var.enable_infrastructure ? 1 : 0
  providers = {
    aws = aws.eu_central_1
  }

  app_name                  = "xelta"
  environment               = var.environment
  region                    = "eu-central-1"

  # Shared Infra Inputs
  vpc_id                      = module.shared_eu_central_1.vpc_id
  private_subnet_ids          = module.shared_eu_central_1.private_subnet_ids
  frontend_alb_listener_arn   = module.shared_eu_central_1.frontend_alb_listener_arn
  alb_security_group_id       = module.shared_eu_central_1.alb_security_group_id

  # App Specific Inputs
  frontend_image            = var.frontend_images["eu-central-1"]
  backend_image             = var.backend_images["eu-central-1"]
  domain_name               = var.domain_name
  route53_zone_id           = data.aws_route53_zone.main.zone_id
  cdn_dns_name              = try(module.cdn[0].cdn_dns_name, "")
  cdn_zone_id               = try(module.cdn[0].cdn_zone_id, "")
  enable_redis              = var.enable_redis
  redis_node_type           = var.redis_node_type
  redis_num_cache_nodes     = var.redis_num_cache_nodes
  enable_websocket_api      = var.enable_websocket_api
  api_gateway_cors_origins  = var.api_gateway_cors_origins
  api_gateway_cors_methods  = var.api_gateway_cors_methods
  api_gateway_cors_headers  = var.api_gateway_cors_headers
  lambda_connect_zip_path   = "${path.module}/lambda/connect.zip"
  lambda_start_job_zip_path = "${path.module}/lambda/start_job.zip"
  lambda_worker_zip_path    = "${path.module}/lambda/worker.zip"
}

# --- AP-SOUTH-1 Stack ---
module "ap_south_1_stack" {
  source = "../../modules/application_regional_stack"
  count  = var.enable_infrastructure ? 1 : 0
  providers = {
    aws = aws.ap_south_1
  }

  app_name                  = "xelta"
  environment               = var.environment
  region                    = "ap-south-1"

  # Shared Infra Inputs
  vpc_id                      = module.shared_ap_south_1.vpc_id
  private_subnet_ids          = module.shared_ap_south_1.private_subnet_ids
  frontend_alb_listener_arn   = module.shared_ap_south_1.frontend_alb_listener_arn
  alb_security_group_id       = module.shared_ap_south_1.alb_security_group_id

  # App Specific Inputs
  frontend_image            = var.frontend_images["ap-south-1"]
  backend_image             = var.backend_images["ap-south-1"]
  domain_name               = var.domain_name
  route53_zone_id           = data.aws_route53_zone.main.zone_id
  cdn_dns_name              = try(module.cdn[0].cdn_dns_name, "")
  cdn_zone_id               = try(module.cdn[0].cdn_zone_id, "")
  enable_redis              = var.enable_redis
  redis_node_type           = var.redis_node_type
  redis_num_cache_nodes     = var.redis_num_cache_nodes
  enable_websocket_api      = var.enable_websocket_api
  api_gateway_cors_origins  = var.api_gateway_cors_origins
  api_gateway_cors_methods  = var.api_gateway_cors_methods
  api_gateway_cors_headers  = var.api_gateway_cors_headers
  lambda_connect_zip_path   = "${path.module}/lambda/connect.zip"
  lambda_start_job_zip_path = "${path.module}/lambda/start_job.zip"
  lambda_worker_zip_path    = "${path.module}/lambda/worker.zip"
}

# WAF & CDN (Global resources)
module "waf" {
  source      = "../../modules/waf"
  count       = var.enable_infrastructure ? 1 : 0
  environment = var.environment
}

module "cdn" {
  source          = "../../modules/cdn"
  count           = var.enable_infrastructure ? 1 : 0
  app_name        = "xelta"
  environment     = var.environment
  domain_name     = var.domain_name
  route53_zone_id = data.aws_route53_zone.main.zone_id
  waf_web_acl_arn = try(module.waf[0].waf_arn, "")

  origins = {
    us-east-1    = try(module.shared_us_east_1.frontend_alb_dns_name, "")
    eu-central-1 = try(module.shared_eu_central_1.frontend_alb_dns_name, "")
    ap-south-1   = try(module.shared_ap_south_1.frontend_alb_dns_name, "")
  }

  certificate_arn = try(module.us_east_1_stack[0].certificate_arn, "")
  # The ACM cert was previously in route53_acm module inside the stack.
  # Now that stack is split.
  # The ACM cert should probably be in the SHARED stack or the APP stack?
  # If it's for the domain, it's shared.
  # But wait, the ACM cert is for CloudFront (us-east-1) and ALBs (regional).
  # The ALBs need certs too if they do HTTPS.
  # Currently, the shared ALB listener is HTTP (port 80).
  # The CDN talks to ALB via HTTP (origin_protocol_policy = "http-only").
  # So the ALB doesn't strictly need a cert if only accessed via CDN.
  # BUT CloudFront needs a cert in us-east-1.
  # Who creates that?
  # Previously: module.route53_acm_us_east_1 created it.
  # Now: It's inside application_regional_stack.
  # So we can get it from us_east_1_stack. However, us_east_1_stack is conditional.
  # If we destroy app stack, we destroy cert. That's fine.
}