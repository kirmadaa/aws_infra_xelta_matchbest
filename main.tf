# Cost Optimization: Local values for conditional deployments
locals {
  # Enable multi-region only for prod, single region for dev/uat
  deploy_regions = var.enable_multi_region && var.environment == "prod" ? var.regions : [var.primary_region]
  
  # Environment-based resource sizing
  cpu_units    = lookup(var.ecs_task_cpu, var.environment, 256)
  memory_mb    = lookup(var.ecs_task_memory, var.environment, 512)
  desired_count = lookup(var.ecs_desired_count, var.environment, 1)
  max_capacity = lookup(var.ecs_max_capacity, var.environment, 2)
  
  # Redis enabled only for specified environments
  redis_enabled = contains(var.redis_enabled_environments, var.environment) && var.enable_redis
  
  # Monitoring settings
  log_retention = lookup(var.log_retention_days, var.environment, 7)
  
  # Cost optimization tags
  common_tags = {
    Environment = var.environment
    Project     = "xelta"
    CostCenter  = "cybersecurity-consulting"
    Owner       = "devops-team"
  }
}

# Data source for Route53 hosted zone
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# Cost Alert: CloudWatch billing alarm
resource "aws_cloudwatch_metric_alarm" "billing_alarm" {
  count               = var.enable_cost_alerts ? 1 : 0
  alarm_name          = "xelta-${var.environment}-monthly-cost-alert"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400"  # 24 hours
  statistic           = "Maximum"
  threshold           = var.monthly_cost_alert_threshold
  alarm_description   = "This metric monitors monthly AWS charges for ${var.environment}"
  alarm_actions       = [aws_sns_topic.cost_alerts[0].arn]
  
  dimensions = {
    Currency = "USD"
  }
  
  tags = local.common_tags
}

# SNS topic for cost alerts
resource "aws_sns_topic" "cost_alerts" {
  count = var.enable_cost_alerts ? 1 : 0
  name  = "xelta-${var.environment}-cost-alerts"
  
  tags = local.common_tags
}

# Global secrets (deploy only in used regions)
dynamic "module" {
  for_each = contains(local.deploy_regions, "us-east-1") ? ["us-east-1"] : []
  content {
    source    = "./modules/secrets"
    providers = { aws = aws.us_east_1 }
    environment = var.environment
  }
}

module "secrets_us_east_1" {
  count     = contains(local.deploy_regions, "us-east-1") ? 1 : 0
  source    = "./modules/secrets"
  providers = { aws = aws.us_east_1 }
  environment = var.environment
}

module "secrets_eu_central_1" {
  count     = contains(local.deploy_regions, "eu-central-1") ? 1 : 0
  source    = "./modules/secrets"
  providers = { aws = aws.eu_central_1 }
  environment = var.environment
}

module "secrets_ap_south_1" {
  count     = contains(local.deploy_regions, "ap-south-1") ? 1 : 0
  source    = "./modules/secrets"
  providers = { aws = aws.ap_south_1 }
  environment = var.environment
}

# WAF & CDN (Global resources - only deploy if multi-region or prod)
module "waf" {
  count       = var.enable_multi_region || var.environment == "prod" ? 1 : 0
  source      = "./modules/waf"
  environment = var.environment
}

module "cdn" {
  count           = var.enable_multi_region || var.environment == "prod" ? 1 : 0
  source          = "./modules/cdn"
  environment     = var.environment
  domain_name     = var.domain_name
  route53_zone_id = data.aws_route53_zone.main.zone_id
  waf_web_acl_arn = length(module.waf) > 0 ? module.waf[0].waf_arn : null

  # Origins based on deployed regions
  origins = {
    for region in local.deploy_regions : region => (
      region == "us-east-1" ? (length(module.ecs_service_us_east_1) > 0 ? module.ecs_service_us_east_1[0].frontend_alb_dns_name : null) :
      region == "eu-central-1" ? (length(module.ecs_service_eu_central_1) > 0 ? module.ecs_service_eu_central_1[0].frontend_alb_dns_name : null) :
      region == "ap-south-1" ? (length(module.ecs_service_ap_south_1) > 0 ? module.ecs_service_ap_south_1[0].frontend_alb_dns_name : null) : null
    )
  }

  # ACM certificate for the CDN (must be in us-east-1)
  certificate_arn = contains(local.deploy_regions, "us-east-1") && length(module.route53_acm_us_east_1) > 0 ? module.route53_acm_us_east_1[0].certificate_arn : null
}

# ==================================
# SERVERLESS BACKEND COMPONENTS
# ==================================

# --- US-EAST-1 ---
resource "aws_dynamodb_table" "jobs_us_east_1" {
  count        = contains(local.deploy_regions, "us-east-1") ? 1 : 0
  provider     = aws.us_east_1
  name         = "xelta-${var.environment}-jobs-us-east-1"
  billing_mode = var.dynamodb_billing_mode
  hash_key     = "jobId"

  attribute {
    name = "jobId"
    type = "S"
  }
  
  # Cost Optimization: Point-in-time recovery only for prod
  point_in_time_recovery {
    enabled = var.environment == "prod"
  }
  
  tags = local.common_tags
}

resource "aws_sqs_queue" "jobs_us_east_1" {
  count    = contains(local.deploy_regions, "us-east-1") ? 1 : 0
  provider = aws.us_east_1
  name     = "xelta-${var.environment}-jobs-us-east-1"
  
  # Cost Optimization: Message retention based on environment
  message_retention_seconds = var.environment == "prod" ? 1209600 : 345600  # 14 days for prod, 4 days for others
  
  tags = local.common_tags
}

resource "aws_s3_bucket" "results_us_east_1" {
  count    = contains(local.deploy_regions, "us-east-1") ? 1 : 0
  provider = aws.us_east_1
  bucket   = "xelta-${var.environment}-results-us-east-1-${random_id.bucket_suffix.hex}"
  
  tags = local.common_tags
}

# Cost Optimization: S3 lifecycle policy
resource "aws_s3_bucket_lifecycle_configuration" "results_us_east_1" {
  count    = contains(local.deploy_regions, "us-east-1") ? 1 : 0
  provider = aws.us_east_1
  bucket   = aws_s3_bucket.results_us_east_1[0].id

  rule {
    id     = "cost_optimization"
    status = "Enabled"

    # Transition to IA after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_INFREQUENT_ACCESS"
    }

    # Transition to Glacier after 90 days
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Delete after retention period
    expiration {
      days = lookup(var.backup_retention_days, var.environment, 30)
    }
  }
}

# --- EU-CENTRAL-1 ---
resource "aws_dynamodb_table" "jobs_eu_central_1" {
  count        = contains(local.deploy_regions, "eu-central-1") ? 1 : 0
  provider     = aws.eu_central_1
  name         = "xelta-${var.environment}-jobs-eu-central-1"
  billing_mode = var.dynamodb_billing_mode
  hash_key     = "jobId"

  attribute {
    name = "jobId"
    type = "S"
  }
  
  point_in_time_recovery {
    enabled = var.environment == "prod"
  }
  
  tags = local.common_tags
}

resource "aws_sqs_queue" "jobs_eu_central_1" {
  count    = contains(local.deploy_regions, "eu-central-1") ? 1 : 0
  provider = aws.eu_central_1
  name     = "xelta-${var.environment}-jobs-eu-central-1"
  
  message_retention_seconds = var.environment == "prod" ? 1209600 : 345600
  
  tags = local.common_tags
}

resource "aws_s3_bucket" "results_eu_central_1" {
  count    = contains(local.deploy_regions, "eu-central-1") ? 1 : 0
  provider = aws.eu_central_1
  bucket   = "xelta-${var.environment}-results-eu-central-1-${random_id.bucket_suffix.hex}"
  
  tags = local.common_tags
}

resource "aws_s3_bucket_lifecycle_configuration" "results_eu_central_1" {
  count    = contains(local.deploy_regions, "eu-central-1") ? 1 : 0
  provider = aws.eu_central_1
  bucket   = aws_s3_bucket.results_eu_central_1[0].id

  rule {
    id     = "cost_optimization"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_INFREQUENT_ACCESS"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = lookup(var.backup_retention_days, var.environment, 30)
    }
  }
}

# --- AP-SOUTH-1 ---
resource "aws_dynamodb_table" "jobs_ap_south_1" {
  count        = contains(local.deploy_regions, "ap-south-1") ? 1 : 0
  provider     = aws.ap_south_1
  name         = "xelta-${var.environment}-jobs-ap-south-1"
  billing_mode = var.dynamodb_billing_mode
  hash_key     = "jobId"

  attribute {
    name = "jobId"
    type = "S"
  }
  
  point_in_time_recovery {
    enabled = var.environment == "prod"
  }
  
  tags = local.common_tags
}

resource "aws_sqs_queue" "jobs_ap_south_1" {
  count    = contains(local.deploy_regions, "ap-south-1") ? 1 : 0
  provider = aws.ap_south_1
  name     = "xelta-${var.environment}-jobs-ap-south-1"
  
  message_retention_seconds = var.environment == "prod" ? 1209600 : 345600
  
  tags = local.common_tags
}

resource "aws_s3_bucket" "results_ap_south_1" {
  count    = contains(local.deploy_regions, "ap-south-1") ? 1 : 0
  provider = aws.ap_south_1
  bucket   = "xelta-${var.environment}-results-ap-south-1-${random_id.bucket_suffix.hex}"
  
  tags = local.common_tags
}

resource "aws_s3_bucket_lifecycle_configuration" "results_ap_south_1" {
  count    = contains(local.deploy_regions, "ap-south-1") ? 1 : 0
  provider = aws.ap_south_1
  bucket   = aws_s3_bucket.results_ap_south_1[0].id

  rule {
    id     = "cost_optimization"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_INFREQUENT_ACCESS"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = lookup(var.backup_retention_days, var.environment, 30)
    }
  }
}

# Random suffix for unique bucket names
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# ===========================
# US-EAST-1 REGION RESOURCES
# ===========================

# --- IAM Role for Lambdas ---
resource "aws_iam_role" "lambda_exec_us_east_1" {
  count    = contains(local.deploy_regions, "us-east-1") ? 1 : 0
  provider = aws.us_east_1
  name     = "xelta-${var.environment}-lambda-exec-us-east-1"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
  
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution_us_east_1" {
  count      = contains(local.deploy_regions, "us-east-1") ? 1 : 0
  provider   = aws.us_east_1
  role       = aws_iam_role.lambda_exec_us_east_1[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Continue with the rest of the Lambda configurations...
# (The file is getting long, so I'll continue in the next update)

# ===========================
# REGION-SPECIFIC DEPLOYMENTS
# ===========================

module "vpc_us_east_1" {
  count   = contains(local.deploy_regions, "us-east-1") ? 1 : 0
  source    = "./modules/vpc"
  providers = { aws = aws.us_east_1 }

  environment        = var.environment
  region             = "us-east-1"
  vpc_cidr           = var.vpc_cidr_blocks["us-east-1"]
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  single_nat_gateway = var.single_nat_gateway
  enable_nat_gateway = var.enable_nat_gateway
  
  tags = local.common_tags
}

module "ecs_service_us_east_1" {
  count   = contains(local.deploy_regions, "us-east-1") ? 1 : 0
  source    = "./modules/ecs_service"
  providers = { aws = aws.us_east_1 }

  environment            = var.environment
  region                 = "us-east-1"
  vpc_id                 = module.vpc_us_east_1[0].vpc_id
  vpc_cidr               = var.vpc_cidr_blocks["us-east-1"]
  private_subnet_ids     = module.vpc_us_east_1[0].private_subnet_ids
  public_subnet_ids      = module.vpc_us_east_1[0].public_subnet_ids
  frontend_image         = var.frontend_images["us-east-1"]
  backend_image          = var.backend_images["us-east-1"]
  
  # Cost optimization: Environment-based sizing
  task_cpu             = local.cpu_units
  task_memory          = local.memory_mb
  desired_count        = local.desired_count
  max_capacity         = local.max_capacity
  enable_spot_capacity = var.ecs_fargate_spot_enabled && var.environment == "dev"
  log_retention_days   = local.log_retention
  
  http_api_vpclink_sg_id = length(aws_security_group.http_api_vpclink_sg_us_east_1) > 0 ? aws_security_group.http_api_vpclink_sg_us_east_1[0].id : null
  
  tags = local.common_tags
}

# Similar pattern for other regions...
module "vpc_eu_central_1" {
  count   = contains(local.deploy_regions, "eu-central-1") ? 1 : 0
  source    = "./modules/vpc"
  providers = { aws = aws.eu_central_1 }

  environment        = var.environment
  region             = "eu-central-1"
  vpc_cidr           = var.vpc_cidr_blocks["eu-central-1"]
  availability_zones = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  single_nat_gateway = var.single_nat_gateway
  enable_nat_gateway = var.enable_nat_gateway
  
  tags = local.common_tags
}

module "vpc_ap_south_1" {
  count   = contains(local.deploy_regions, "ap-south-1") ? 1 : 0
  source    = "./modules/vpc"
  providers = { aws = aws.ap_south_1 }

  environment        = var.environment
  region             = "ap-south-1"
  vpc_cidr           = var.vpc_cidr_blocks["ap-south-1"]
  availability_zones = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
  single_nat_gateway = var.single_nat_gateway
  enable_nat_gateway = var.enable_nat_gateway
  
  tags = local.common_tags
}

# Redis modules with cost optimization
module "redis_us_east_1" {
  count     = contains(local.deploy_regions, "us-east-1") && local.redis_enabled ? 1 : 0
  source    = "./modules/elasticache_redis"
  providers = { aws = aws.us_east_1 }

  environment                = var.environment
  region                     = "us-east-1"
  vpc_id                     = module.vpc_us_east_1[0].vpc_id
  private_subnet_ids         = module.vpc_us_east_1[0].private_subnet_ids
  node_type                  = var.redis_node_type
  num_cache_nodes            = var.redis_num_cache_nodes
  allowed_security_group_ids = length(module.ecs_service_us_east_1) > 0 ? [module.ecs_service_us_east_1[0].service_security_group_id] : []
  
  tags = local.common_tags
}

module "redis_eu_central_1" {
  count     = contains(local.deploy_regions, "eu-central-1") && local.redis_enabled ? 1 : 0
  source    = "./modules/elasticache_redis"
  providers = { aws = aws.eu_central_1 }

  environment                = var.environment
  region                     = "eu-central-1"
  vpc_id                     = module.vpc_eu_central_1[0].vpc_id
  private_subnet_ids         = module.vpc_eu_central_1[0].private_subnet_ids
  node_type                  = var.redis_node_type
  num_cache_nodes            = var.redis_num_cache_nodes
  allowed_security_group_ids = length(module.ecs_service_eu_central_1) > 0 ? [module.ecs_service_eu_central_1[0].service_security_group_id] : []
  
  tags = local.common_tags
}

module "redis_ap_south_1" {
  count     = contains(local.deploy_regions, "ap-south-1") && local.redis_enabled ? 1 : 0
  source    = "./modules/elasticache_redis"
  providers = { aws = aws.ap_south_1 }

  environment                = var.environment
  region                     = "ap-south-1"
  vpc_id                     = module.vpc_ap_south_1[0].vpc_id
  private_subnet_ids         = module.vpc_ap_south_1[0].private_subnet_ids
  node_type                  = var.redis_node_type
  num_cache_nodes            = var.redis_num_cache_nodes
  allowed_security_group_ids = length(module.ecs_service_ap_south_1) > 0 ? [module.ecs_service_ap_south_1[0].service_security_group_id] : []
  
  tags = local.common_tags
}