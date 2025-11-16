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

# --- Global Resources ---
module "waf" {
  source      = "../../modules/waf"
  environment = var.environment
}

# Note: The 'cdn' module is defined at the end of the file after all regional ALBs are created.

# --- Regional VPCs ---
module "vpc_us_east_1" {
  source    = "../../modules/vpc"
  providers = { aws = aws.us_east_1 }
  # ... vpc variables ...
  environment = var.environment
  region      = "us-east-1"
  vpc_cidr    = var.vpc_cidr_blocks["us-east-1"]
  # ... other variables
}

module "vpc_eu_central_1" {
  source    = "../../modules/vpc"
  providers = { aws = aws.eu_central_1 }
  # ... vpc variables ...
    environment = var.environment
  region      = "eu-central-1"
  vpc_cidr    = var.vpc_cidr_blocks["eu-central-1"]
}

module "vpc_ap_south_1" {
  source    = "../../modules/vpc"
  providers = { aws = aws.ap_south_1 }
  # ... vpc variables ...
    environment = var.environment
  region      = "ap-south-1"
  vpc_cidr    = var.vpc_cidr_blocks["ap-south-1"]
}

# --- SHARED PLATFORM: US-EAST-1 ---
resource "aws_ecs_cluster" "shared_us_east_1" {
  provider = aws.us_east_1
  name     = "shared-${var.environment}-us-east-1"
}

resource "aws_lb" "shared_alb_us_east_1" {
  provider           = aws.us_east_1
  name               = "shared-${var.environment}-us-east-1"
  load_balancer_type = "application"
  subnets            = module.vpc_us_east_1.public_subnet_ids
  security_groups    = [aws_security_group.alb_sg_us_east_1.id]
}

resource "aws_lb_listener" "http_us_east_1" {
  provider          = aws.us_east_1
  load_balancer_arn = aws_lb.shared_alb_us_east_1.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: Not Found"
      status_code  = "404"
    }
  }
}

resource "aws_security_group" "alb_sg_us_east_1" {
  provider    = aws.us_east_1
  name        = "xelta-${var.environment}-alb-us-east-1"
  description = "Allow HTTP traffic from CloudFront"
  vpc_id      = module.vpc_us_east_1.vpc_id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- SHARED PLATFORM: EU-CENTRAL-1 ---
resource "aws_ecs_cluster" "shared_eu_central_1" {
  provider = aws.eu_central_1
  name     = "shared-${var.environment}-eu-central-1"
}

resource "aws_lb" "shared_alb_eu_central_1" {
  provider           = aws.eu_central_1
  name               = "shared-${var.environment}-eu-central-1"
  load_balancer_type = "application"
  subnets            = module.vpc_eu_central_1.public_subnet_ids
  security_groups    = [aws_security_group.alb_sg_eu_central_1.id]
}

resource "aws_lb_listener" "http_eu_central_1" {
  provider          = aws.eu_central_1
  load_balancer_arn = aws_lb.shared_alb_eu_central_1.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: Not Found"
      status_code  = "404"
    }
  }
}

resource "aws_security_group" "alb_sg_eu_central_1" {
  provider    = aws.eu_central_1
  name        = "xelta-${var.environment}-alb-eu-central-1"
  description = "Allow HTTP traffic from CloudFront"
  vpc_id      = module.vpc_eu_central_1.vpc_id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- SHARED PLATFORM: AP-SOUTH-1 ---
resource "aws_ecs_cluster" "shared_ap_south_1" {
  provider = aws.ap_south_1
  name     = "shared-${var.environment}-ap-south-1"
}

resource "aws_lb" "shared_alb_ap_south_1" {
  provider           = aws.ap_south_1
  name               = "shared-${var.environment}-ap-south-1"
  load_balancer_type = "application"
  subnets            = module.vpc_ap_south_1.public_subnet_ids
  security_groups    = [aws_security_group.alb_sg_ap_south_1.id]
}

resource "aws_lb_listener" "http_ap_south_1" {
  provider          = aws.ap_south_1
  load_balancer_arn = aws_lb.shared_alb_ap_south_1.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: Not Found"
      status_code  = "404"
    }
  }
}

resource "aws_security_group" "alb_sg_ap_south_1" {
  provider    = aws.ap_south_1
  name        = "xelta-${var.environment}-alb-ap-south-1"
  description = "Allow HTTP traffic from CloudFront"
  vpc_id      = module.vpc_ap_south_1.vpc_id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}


# --- Xelta Application ---
module "xelta_us_east_1" {
  source = "../../apps/xelta"
  providers = { aws = aws.us_east_1 }

  enable_xelta                 = lookup(var.xelta_region_config, "us-east-1", false)
  environment                  = var.environment
  region                       = "us-east-1"
  frontend_image               = var.frontend_images["us-east-1"]
  backend_image                = var.backend_images["us-east-1"]
  vpc_id                       = module.vpc_us_east_1.vpc_id
  private_subnet_ids           = module.vpc_us_east_1.private_subnet_ids
  shared_cluster_id            = aws_ecs_cluster.shared_us_east_1.id
  shared_cluster_name          = aws_ecs_cluster.shared_us_east_1.name
  shared_listener_arn          = aws_lb_listener.http_us_east_1.arn
  shared_alb_security_group_id = aws_security_group.alb_sg_us_east_1.id
}

module "xelta_eu_central_1" {
  source = "../../apps/xelta"
  providers = { aws = aws.eu_central_1 }

  enable_xelta                 = lookup(var.xelta_region_config, "eu-central-1", false)
  environment                  = var.environment
  region                       = "eu-central-1"
  frontend_image               = var.frontend_images["eu-central-1"]
  backend_image                = var.backend_images["eu-central-1"]
  vpc_id                       = module.vpc_eu_central_1.vpc_id
  private_subnet_ids           = module.vpc_eu_central_1.private_subnet_ids
  shared_cluster_id            = aws_ecs_cluster.shared_eu_central_1.id
  shared_cluster_name          = aws_ecs_cluster.shared_eu_central_1.name
  shared_listener_arn          = aws_lb_listener.http_eu_central_1.arn
  shared_alb_security_group_id = aws_security_group.alb_sg_eu_central_1.id
}

module "xelta_ap_south_1" {
  source = "../../apps/xelta"
  providers = { aws = aws.ap_south_1 }

  enable_xelta                 = lookup(var.xelta_region_config, "ap-south-1", false)
  environment                  = var.environment
  region                       = "ap-south-1"
  frontend_image               = var.frontend_images["ap-south-1"]
  backend_image                = var.backend_images["ap-south-1"]
  vpc_id                       = module.vpc_ap_south_1.vpc_id
  private_subnet_ids           = module.vpc_ap_south_1.private_subnet_ids
  shared_cluster_id            = aws_ecs_cluster.shared_ap_south_1.id
  shared_cluster_name          = aws_ecs_cluster.shared_ap_south_1.name
  shared_listener_arn          = aws_lb_listener.http_ap_south_1.arn
  shared_alb_security_group_id = aws_security_group.alb_sg_ap_south_1.id
}

# --- CDN Module (Now correctly wired to shared ALBs) ---
module "cdn" {
  source      = "../../modules/cdn"
  environment = var.environment
  domain_name = var.domain_name
  # ... other cdn variables ...
  route53_zone_id = data.aws_route53_zone.main.zone_id
  waf_web_acl_arn = module.waf.waf_arn

  origins = {
    "us-east-1"    = aws_lb.shared_alb_us_east_1.dns_name
    "eu-central-1" = aws_lb.shared_alb_eu_central_1.dns_name
    "ap-south-1"   = aws_lb.shared_alb_ap_south_1.dns_name
  }
}
