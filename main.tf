# Provider configuration for multiple regions
provider "aws" {
  region = "us-east-1"
  alias  = "us_east_1"
}

provider "aws" {
  region = "eu-central-1"
  alias  = "eu_central_1"
}

provider "aws" {
  region = "ap-south-1"
  alias  = "ap_south_1"
}

# Backend configuration
terraform {
  backend "s3" {}
}

# Data source for Route53 hosted zone
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# Global secrets (stored in us-east-1, replicated to other regions)
module "secrets_us_east_1" {
  source      = "./modules/secrets"
  providers   = { aws = aws.us_east_1 }
  environment = var.environment
}

module "secrets_eu_central_1" {
  source      = "./modules/secrets"
  providers   = { aws = aws.eu_central_1 }
  environment = var.environment
}

module "secrets_ap_south_1" {
  source      = "./modules/secrets"
  providers   = { aws = aws.ap_south_1 }
  environment = var.environment
}

# WAF & CDN (Global resources)
module "waf" {
  source      = "./modules/waf"
  environment = var.environment
}

module "cdn" {
  source          = "./modules/cdn"
  environment     = var.environment
  domain_name     = var.domain_name
  route53_zone_id = data.aws_route53_zone.main.zone_id
  waf_web_acl_arn = module.waf.waf_arn

  origins = {
    us-east-1    = module.xelta_us_east_1.frontend_alb_dns_name
    eu-central-1 = module.xelta_eu_central_1.frontend_alb_dns_name
    ap-south-1   = module.xelta_ap_south_1.frontend_alb_dns_name
  }

  certificate_arn = module.route53_acm_us_east_1.certificate_arn
}

# --- Regional Resources ---
module "vpc_us_east_1" {
  source    = "./modules/vpc"
  providers = { aws = aws.us_east_1 }

  environment        = var.environment
  region             = "us-east-1"
  vpc_cidr           = var.vpc_cidr_blocks["us-east-1"]
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  single_nat_gateway = var.environment == "dev" ? true : false
}

module "vpc_eu_central_1" {
  source    = "./modules/vpc"
  providers = { aws = aws.eu_central_1 }

  environment        = var.environment
  region             = "eu-central-1"
  vpc_cidr           = var.vpc_cidr_blocks["eu-central-1"]
  availability_zones = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  single_nat_gateway = var.environment == "dev" ? true : false
}

module "vpc_ap_south_1" {
  source    = "./modules/vpc"
  providers = { aws = aws.ap_south_1 }

  environment        = var.environment
  region             = "ap-south-1"
  vpc_cidr           = var.vpc_cidr_blocks["ap-south-1"]
  availability_zones = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
  single_nat_gateway = var.environment == "dev" ? true : false
}

# --- Xelta Application ---
module "xelta_us_east_1" {
  source = "./apps/xelta"
  providers = { aws = aws.us_east_1 }

  enable_xelta     = var.enable_xelta
  environment      = var.environment
  region           = "us-east-1"
  frontend_image   = var.frontend_images["us-east-1"]
  backend_image    = var.backend_images["us-east-1"]
  vpc_id           = module.vpc_us_east_1.vpc_id
  vpc_cidr         = var.vpc_cidr_blocks["us-east-1"]
  private_subnet_ids = module.vpc_us_east_1.private_subnet_ids
  public_subnet_ids  = module.vpc_us_east_1.public_subnet_ids
}

module "xelta_eu_central_1" {
  source = "./apps/xelta"
  providers = { aws = aws.eu_central_1 }

  enable_xelta     = var.enable_xelta
  environment      = var.environment
  region           = "eu-central-1"
  frontend_image   = var.frontend_images["eu-central-1"]
  backend_image    = var.backend_images["eu-central-1"]
  vpc_id           = module.vpc_eu_central_1.vpc_.id
  vpc_cidr         = var.vpc_cidr_blocks["eu-central-1"]
  private_subnet_ids = module.vpc_eu_central_1.private_subnet_ids
  public_subnet_ids  = module.vpc_eu_central_1.public_subnet_ids
}

module "xelta_ap_south_1" {
  source = "./apps/xelta"
  providers = { aws = aws.ap_south_1 }

  enable_xelta     = var.enable_xelta
  environment      = var.environment
  region           = "ap-south-1"
  frontend_image   = var.frontend_images["ap-south-1"]
  backend_image    = var.backend_images["ap-south-1"]
  vpc_id           = module.vpc_ap_south_1.vpc_id
  vpc_cidr         = var.vpc_cidr_blocks["ap-south-1"]
  private_subnet_ids = module.vpc_ap_south_1.private_subnet_ids
  public_subnet_ids  = module.vpc_ap_south_1.public_subnet_ids
}
