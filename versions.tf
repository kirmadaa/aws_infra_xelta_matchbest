# Remote state backend configuration
# S3 bucket and DynamoDB table must be created before running terraform init
terraform {
  backend "s3" {
    bucket         = "xeltainfrastatefiles"
    key            = "xelta-infrastructure/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "xelta-terraform-locks"

    # Use workspaces to separate dev/uat/prod state
    # Actual key will be: xelta-infrastructure/env:/{workspace}/terraform.tfstate
  }
}

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# Default provider (us-east-1)
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "xelta"
      Owner       = "infra"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}

# Multi-region provider aliases
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "xelta"
      Owner       = "infra"
      ManagedBy   = "terraform"
      Environment = var.environment
      Region      = "us-east-1"
    }
  }
}

provider "aws" {
  alias  = "eu_central_1"
  region = "eu-central-1"

  default_tags {
    tags = {
      Project     = "xelta"
      Owner       = "infra"
      ManagedBy   = "terraform"
      Environment = var.environment
      Region      = "eu-central-1"
    }
  }
}

provider "aws" {
  alias  = "ap_south_1"
  region = "ap-south-1"

  default_tags {
    tags = {
      Project     = "xelta"
      Owner       = "infra"
      ManagedBy   = "terraform"
      Environment = var.environment
      Region      = "ap-south-1"
    }
  }
}