module "vpc" {
  source    = "../vpc"

  environment        = var.environment
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  single_nat_gateway = var.single_nat_gateway
  enable_ec2_nat_instance = var.enable_ec2_nat_instance
}


# --- Shared Security Groups ---

resource "aws_security_group" "alb_sg" {
  name        = "shared-${var.environment}-${var.region}-alb"
  description = "Allow HTTP traffic from VPC (for CDN)"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"] # Open to world for now, or restrict to CloudFront
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "nlb_sg" {
  name        = "shared-${var.environment}-${var.region}-nlb"
  description = "Allow TCP traffic from VPC"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    cidr_blocks     = [var.vpc_cidr] # Allow internal traffic
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Shared ALB ---
resource "aws_lb" "frontend_alb" {
  name               = "shared-fe-${var.environment}-${var.region}"
  internal           = false
  load_balancer_type = "application"
  subnets            = module.vpc.public_subnet_ids
  security_groups    = [aws_security_group.alb_sg.id]

  tags = {
    Name = "shared-${var.environment}-frontend-alb"
  }
}

resource "aws_lb_listener" "frontend_http" {
  load_balancer_arn = aws_lb.frontend_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

# --- Shared NLB ---
resource "aws_lb" "backend_nlb" {
  name               = "shared-${var.environment}-${var.region}-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = module.vpc.private_subnet_ids
  security_groups    = [aws_security_group.nlb_sg.id]

  tags = {
    Name = "shared-${var.environment}-backend-nlb"
  }
}

# Listener removed to avoid port conflicts with application stacks.
# Applications will create their own listeners on the shared NLB.
