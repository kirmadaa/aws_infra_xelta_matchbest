terraform {
  required_version = ">= 1.0"
  backend "s3" {
     Configure your S3 backend here
     bucket         = "xeltainfrastatefiles"
     key            = "xelta-dev-eu-west-3.tfstate"
     region         = "eu-west-3"
     dynamodb_table = "xelta-terraform-locks"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  project_name = "xelta-${var.environment}"
}

module "vpc" {
  source       = "../../../modules/vpc"
  project_name = local.project_name
  aws_region   = var.aws_region
  vpc_cidr     = var.vpc_cidr
}

resource "aws_security_group" "alb" {
  name        = "${local.project_name}-alb-sg"
  description = "Security group for the Application Load Balancer"
  vpc_id      = module.vpc.vpc_id

  # Allow inbound HTTPS from anywhere (CloudFront)
  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "eks" {
  source               = "../../../modules/eks"
  project_name         = local.project_name
  aws_region           = var.aws_region
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  eks_cluster_version  = var.eks_cluster_version
  eks_instance_types   = var.eks_instance_types
  eks_min_nodes        = var.eks_min_nodes
  eks_max_nodes        = var.eks_max_nodes
}

module "database" {
  source                     = "../../../modules/database"
  project_name               = local.project_name
  environment                = var.environment
  vpc_id                     = module.vpc.vpc_id
  database_subnet_ids        = module.vpc.database_subnet_ids
  eks_node_security_group_id = module.eks.node_security_group_id
  db_skip_final_snapshot     = var.db_skip_final_snapshot
  aurora_instance_class      = var.aurora_instance_class

  redis_node_type            = var.redis_node_type
  redis_node_count           = var.redis_node_count
}

module "edge" {
  source                = "../../../modules/edge"
  project_name          = local.project_name
  domain_name           = var.domain_name
  parent_zone_id        = var.parent_zone_id
  alb_security_group_id = aws_security_group.alb.id
}
