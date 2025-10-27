# PROVIDERS & BACKEND (from backend.tf)

# GLOBAL RESOURCES (WAF, CDN, Route53)
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

module "waf" {
  source      = "./modules/waf"
  environment = var.environment
}

module "route53_acm" {
  source    = "./modules/route53_acm"
  providers = { aws = aws.us-east-1 } # ACM cert for CloudFront must be in us-east-1

  environment     = var.environment
  domain_name     = var.domain_name
  route53_zone_id = data.aws_route53_zone.main.zone_id
  cdn_dns_name    = module.cdn.cdn_dns_name
  cdn_zone_id     = module.cdn.cdn_zone_id
}

module "cdn" {
  source          = "./modules/cdn"
  environment     = var.environment
  domain_name     = var.domain_name
  route53_zone_id = data.aws_route53_zone.main.zone_id
  waf_web_acl_arn = module.waf.waf_arn
  certificate_arn = module.route53_acm.certificate_arn

  origins = { for k, v in module.regional_stack : k => v.frontend_alb_dns_name }
}

# REGIONAL STACKS
module "regional_stack" {
  for_each = var.regional_configs
  source   = "./modules/regional_stack"

  providers = {
    aws = aws[each.key]
  }

  # REGIONAL PARAMS
  environment        = var.environment
  region             = each.value.region
  domain_name        = var.domain_name
  route53_zone_id    = data.aws_route53_zone.main.zone_id
  frontend_image     = each.value.frontend_image
  backend_image      = each.value.backend_image
  vpc_cidr           = each.value.vpc_cidr
  availability_zones = each.value.availability_zones
  single_nat_gateway = each.value.single_nat_gateway

  # GLOBAL PARAMS
  ecs_task_cpu               = var.ecs_task_cpu
  ecs_task_memory            = var.ecs_task_memory
  enable_redis               = var.enable_redis
  redis_node_type            = var.redis_node_type
  redis_num_cache_nodes      = var.redis_num_cache_nodes
  api_gateway_cors_origins   = var.api_gateway_cors_origins
  api_gateway_cors_methods   = var.api_gateway_cors_methods
  api_gateway_cors_headers   = var.api_gateway_cors_headers
  lambda_memory_size         = var.lambda_memory_size
  enable_container_insights   = var.enable_container_insights
  enable_lambda_insights     = var.enable_lambda_insights
  cloudwatch_log_retention_days = var.cloudwatch_log_retention_days
  alarm_sns_topic_arn        = var.alarm_sns_topic_arn
  alarm_evaluation_periods   = var.alarm_evaluation_periods
  alarm_period_seconds       = var.alarm_period_seconds
  alarm_threshold            = var.alarm_threshold
}
