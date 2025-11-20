module "vpc" {
  source    = "../vpc"

  environment        = var.environment
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  single_nat_gateway = var.single_nat_gateway
  enable_ec2_nat_instance = var.enable_ec2_nat_instance
}

# --- ECS Cluster ---
resource "aws_ecs_cluster" "main" {
  name = "shared-${var.environment}-${var.region}"
}

# --- IAM Role for ECS Task Execution (Shared) ---
resource "aws_iam_role" "ecs_task_execution" {
  name = "shared-${var.environment}-${var.region}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "ecs_exec" {
  name        = "shared-${var.environment}-${var.region}-ecs-exec-policy"
  description = "Allow ECS tasks to be accessed via ECS Exec"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_exec" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = aws_iam_policy.ecs_exec.arn
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

resource "aws_lb_listener" "backend_tcp" {
  load_balancer_arn = aws_lb.backend_nlb.arn
  port              = 8080
  protocol          = "TCP"

  default_action {
    type             = "forward"
    # This is tricky for NLB, usually needs a target group.
    # For shared NLB, we might need a dummy target group or just leave it empty if possible?
    # Actually, NLB listeners MUST forward to a target group.
    # We will create a default dummy target group.
    target_group_arn = aws_lb_target_group.dummy_tcp.arn
  }
}

resource "aws_lb_target_group" "dummy_tcp" {
  name_prefix = "dummy-"
  port        = 8080
  protocol    = "TCP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"
}
