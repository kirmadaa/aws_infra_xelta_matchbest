# Data source for Route53 hosted zone
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# Global KMS key (replicated to all regions for secrets encryption)
module "kms" {
  source      = "./modules/kms"
  environment = var.environment
}

# Global secrets (stored in us-east-1, replicated to other regions)
module "secrets" {
  source       = "./modules/secrets"
  environment  = var.environment
  kms_key_id   = module.kms.kms_key_id
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
}

module "eks_us_east_1" {
  source    = "./modules/eks"
  providers = { aws = aws.us_east_1 }

  environment         = var.environment
  region              = "us-east-1"
  cluster_version     = var.eks_version
  vpc_id              = module.vpc_us_east_1.vpc_id
  private_subnet_ids  = module.vpc_us_east_1.private_subnet_ids

  node_instance_types = var.eks_node_instance_types
  node_desired_size   = var.eks_node_desired_size
  node_min_size       = var.eks_node_min_size
  node_max_size       = var.eks_node_max_size

  kms_key_arn         = module.kms.kms_key_arn
}

module "alb_us_east_1" {
  source    = "./modules/alb_ingress"
  providers = { aws = aws.us_east_1 }

  environment       = var.environment
  region            = "us-east-1"
  vpc_id            = module.vpc_us_east_1.vpc_id
  public_subnet_ids = module.vpc_us_east_1.public_subnet_ids

  certificate_arn   = module.route53_acm_us_east_1.certificate_arn
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
  kms_key_id      = module.kms.kms_key_arn

  allowed_security_group_ids = [module.eks_us_east_1.node_security_group_id]
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
  kms_key_id     = module.kms.kms_key_arn
  db_secret_arn  = module.secrets.db_secret_arn

  allowed_security_group_ids = [module.eks_us_east_1.node_security_group_id]
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
}

module "eks_eu_central_1" {
  source    = "./modules/eks"
  providers = { aws = aws.eu_central_1 }

  environment         = var.environment
  region              = "eu-central-1"
  cluster_version     = var.eks_version
  vpc_id              = module.vpc_eu_central_1.vpc_id
  private_subnet_ids  = module.vpc_eu_central_1.private_subnet_ids

  node_instance_types = var.eks_node_instance_types
  node_desired_size   = var.eks_node_desired_size
  node_min_size       = var.eks_node_min_size
  node_max_size       = var.eks_node_max_size

  kms_key_arn         = module.kms.kms_key_arn
}

module "alb_eu_central_1" {
  source    = "./modules/alb_ingress"
  providers = { aws = aws.eu_central_1 }

  environment       = var.environment
  region            = "eu-central-1"
  vpc_id            = module.vpc_eu_central_1.vpc_id
  public_subnet_ids = module.vpc_eu_central_1.public_subnet_ids

  certificate_arn   = module.route53_acm_eu_central_1.certificate_arn
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
  kms_key_id      = module.kms.kms_key_arn

  allowed_security_group_ids = [module.eks_eu_central_1.node_security_group_id]
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
  kms_key_id     = module.kms.kms_key_arn
  db_secret_arn  = module.secrets.db_secret_arn

  allowed_security_group_ids = [module.eks_eu_central_1.node_security_group_id]
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
}

module "eks_ap_south_1" {
  source    = "./modules/eks"
  providers = { aws = aws.ap_south_1 }

  environment         = var.environment
  region              = "ap-south-1"
  cluster_version     = var.eks_version
  vpc_id              = module.vpc_ap_south_1.vpc_id
  private_subnet_ids  = module.vpc_ap_south_1.private_subnet_ids

  node_instance_types = var.eks_node_instance_types
  node_desired_size   = var.eks_node_desired_size
  node_min_size       = var.eks_node_min_size
  node_max_size       = var.eks_node_max_size

  kms_key_arn         = module.kms.kms_key_arn
}

module "alb_ap_south_1" {
  source    = "./modules/alb_ingress"
  providers = { aws = aws.ap_south_1 }

  environment       = var.environment
  region            = "ap-south-1"
  vpc_id            = module.vpc_ap_south_1.vpc_id
  public_subnet_ids = module.vpc_ap_south_1.public_subnet_ids

  certificate_arn   = module.route53_acm_ap_south_1.certificate_arn
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
  kms_key_id      = module.kms.kms_key_arn

  allowed_security_group_ids = [module.eks_ap_south_1.node_security_group_id]
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
  kms_key_id     = module.kms.kms_key_arn
  db_secret_arn  = module.secrets.db_secret_arn

  allowed_security_group_ids = [module.eks_ap_south_1.node_security_group_id]
}