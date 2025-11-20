# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "xelta-${var.environment}-vpc-endpoints-${var.region}"
  description = "Security group for VPC interface endpoints"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
    description = "Allow HTTPS from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name        = "xelta-${var.environment}-vpc-endpoints-${var.region}"
    Environment = var.environment
  }
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

# ==========================================
# Gateway Endpoints (Free, S3 & DynamoDB)
# ==========================================

# S3 Gateway Endpoint
resource "aws_vpc_endpoint" "s3" {
  count        = var.enable_s3_endpoint ? 1 : 0
  vpc_id       = var.vpc_id
  service_name = "com.amazonaws.${var.region}.s3"

  route_table_ids = var.private_route_table_ids

  tags = {
    Name        = "xelta-${var.environment}-s3-endpoint-${var.region}"
    Environment = var.environment
  }
}

# DynamoDB Gateway Endpoint
resource "aws_vpc_endpoint" "dynamodb" {
  count        = var.enable_dynamodb_endpoint ? 1 : 0
  vpc_id       = var.vpc_id
  service_name = "com.amazonaws.${var.region}.dynamodb"

  route_table_ids = var.private_route_table_ids

  tags = {
    Name        = "xelta-${var.environment}-dynamodb-endpoint-${var.region}"
    Environment = var.environment
  }
}

# ==========================================
# Interface Endpoints (Priced, but worth it)
# ==========================================

# ECR API Endpoint
resource "aws_vpc_endpoint" "ecr_api" {
  count               = var.enable_ecr_endpoints ? 1 : 0
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "xelta-${var.environment}-ecr-api-endpoint-${var.region}"
    Environment = var.environment
  }
}

# ECR Docker Endpoint
resource "aws_vpc_endpoint" "ecr_dkr" {
  count               = var.enable_ecr_endpoints ? 1 : 0
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "xelta-${var.environment}-ecr-dkr-endpoint-${var.region}"
    Environment = var.environment
  }
}

# Secrets Manager Endpoint
resource "aws_vpc_endpoint" "secretsmanager" {
  count               = var.enable_secrets_endpoint ? 1 : 0
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "xelta-${var.environment}-secretsmanager-endpoint-${var.region}"
    Environment = var.environment
  }
}

# CloudWatch Logs Endpoint (for Lambda and ECS logs)
resource "aws_vpc_endpoint" "logs" {
  count               = var.enable_ecr_endpoints ? 1 : 0  # Piggyback on ECR flag
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "xelta-${var.environment}-logs-endpoint-${var.region}"
    Environment = var.environment
  }
}
