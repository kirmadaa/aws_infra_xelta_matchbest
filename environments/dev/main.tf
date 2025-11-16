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

# --- Shared Platform Resources ---

# --- Regional Resources ---
module "vpc_us_east_1" {
  source    = "../../modules/vpc"
  providers = { aws = aws.us_east_1 }

  environment        = var.environment
  region             = "us-east-1"
  vpc_cidr           = var.vpc_cidr_blocks["us-east-1"]
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  single_nat_gateway = var.environment == "dev" ? true : false
}

module "vpc_eu_central_1" {
  source    = "../../modules/vpc"
  providers = { aws = aws.eu_central_1 }

  environment        = var.environment
  region             = "eu-central-1"
  vpc_cidr           = var.vpc_cidr_blocks["eu-central-1"]
  availability_zones = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  single_nat_gateway = var.environment == "dev" ? true : false
}

module "vpc_ap_south_1" {
  source    = "../../modules/vpc"
  providers = { aws = aws.ap_south_1 }

  environment        = var.environment
  region             = "ap-south-1"
  vpc_cidr           = var.vpc_cidr_blocks["ap-south-1"]
  availability_zones = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
  single_nat_gateway = var.environment == "dev" ? true : false
}

# --- Shared ECS Cluster ---
resource "aws_ecs_cluster" "main" {
  name = "xelta-${var.environment}-shared-cluster"
}

# --- Shared Application Load Balancer ---
resource "aws_lb" "shared_alb" {
  name               = "xelta-${var.environment}-shared-alb"
  load_balancer_type = "application"
  subnets            = module.vpc_us_east_1.public_subnet_ids # Assuming single region for ALB for now
  security_groups    = [aws_security_group.alb_sg.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.shared_alb.arn
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

# --- Security Groups ---
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "alb_sg" {
  name        = "xelta-${var.environment}-alb"
  description = "Allow HTTP traffic from VPC (for CDN)"
  vpc_id      = module.vpc_us_east_1.vpc_id # Assuming single region for SG for now

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

# --- Xelta Application ---
module "xelta_us_east_1" {
  source = "../../apps/xelta"
  providers = { aws = aws.us_east_1 }

  enable_xelta        = var.enable_xelta
  environment         = var.environment
  region              = "us-east-1"
  frontend_image      = var.frontend_images["us-east-1"]
  backend_image       = var.backend_images["us-east-1"]
  vpc_id              = module.vpc_us_east_1.vpc_id
  private_subnet_ids    = module.vpc_us_east_1.private_subnet_ids
  shared_cluster_id   = aws_ecs_cluster.main.id
  shared_listener_arn = aws_lb_listener.http.arn
}

module "xelta_eu_central_1" {
  source = "../../apps/xelta"
  providers = { aws = aws.eu_central_1 }

  enable_xelta        = var.enable_xelta
  environment         = var.environment
  region              = "eu-central-1"
  frontend_image      = var.frontend_images["eu-central-1"]
  backend_image       = var.backend_images["eu-central-1"]
  vpc_id              = module.vpc_eu_central_1.vpc_id
  private_subnet_ids    = module.vpc_eu_central_1.private_subnet_ids
  shared_cluster_id   = aws_ecs_cluster.main.id
  shared_listener_arn = aws_lb_listener.http.arn
}

module "xelta_ap_south_1" {
  source = "../../apps/xelta"
  providers = { aws = aws.ap_south_1 }

  enable_xelta        = var.enable_xelta
  environment         = var.environment
  region              = "ap-south-1"
  frontend_image      = var.frontend_images["ap-south-1"]
  backend_image       = var.backend_images["ap-south-1"]
  vpc_id              = module.vpc_ap_south_1.vpc_id
  private_subnet_ids    = module.vpc_ap_south_1.private_subnet_ids
  shared_cluster_id   = aws_ecs_cluster.main.id
  shared_listener_arn = aws_lb_listener.http.arn
}
