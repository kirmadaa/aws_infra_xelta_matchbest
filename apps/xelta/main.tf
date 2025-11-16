# ECS Cluster
resource "aws_ecs_cluster" "main" {
  count = var.enable_xelta ? 1 : 0
  name  = "xelta-${var.environment}-${var.region}"
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution" {
  count = var.enable_xelta ? 1 : 0
  name  = "xelta-${var.environment}-${var.region}-ecs-task-execution-role"

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
  count      = var.enable_xelta ? 1 : 0
  role       = aws_iam_role.ecs_task_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- Frontend Service ---
module "frontend" {
  source = "../../modules/microservice"

  count        = var.enable_xelta ? 1 : 0
  environment  = var.environment
  region       = var.region
  service_name = "frontend"
  docker_image = var.frontend_image

  ecs_cluster_id                = aws_ecs_cluster.main[0].id
  ecs_cluster_name              = aws_ecs_cluster.main[0].name
  ecs_task_execution_role_arn   = aws_iam_role.ecs_task_execution[0].arn
  private_subnet_ids            = var.private_subnet_ids
  ecs_service_security_group_id = aws_security_group.ecs_service[0].id
  target_group_arn              = aws_lb_target_group.frontend_http[0].arn
  container_port                = 3000
}

# --- Backend Service ---
module "backend" {
  source = "../../modules/microservice"

  count        = var.enable_xelta ? 1 : 0
  environment  = var.environment
  region       = var.region
  service_name = "backend"
  docker_image = var.backend_image

  ecs_cluster_id                = aws_ecs_cluster.main[0].id
  ecs_cluster_name              = aws_ecs_cluster.main[0].name
  ecs_task_execution_role_arn   = aws_iam_role.ecs_task_execution[0].arn
  private_subnet_ids            = var.private_subnet_ids
  ecs_service_security_group_id = aws_security_group.ecs_service[0].id
  target_group_arn              = aws_lb_target_group.backend_tcp[0].arn
  container_port                = 5000
}

# --- Networking ---
resource "aws_lb" "frontend_alb" {
  count              = var.enable_xelta ? 1 : 0
  name               = "xl-fe-${var.environment}-${var.region}"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb_sg[0].id]

  tags = {
    Name = "xelta-${var.environment}-frontend-alb"
  }
}

resource "aws_lb_target_group" "frontend_http" {
  count       = var.enable_xelta ? 1 : 0
  name_prefix = "xl-f-"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol = "HTTP"
    path     = "/"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "frontend_http" {
  count             = var.enable_xelta ? 1 : 0
  load_balancer_arn = aws_lb.frontend_alb[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_http[0].arn
  }
}

resource "aws_lb" "backend_nlb" {
  count              = var.enable_xelta ? 1 : 0
  name               = "xelta-${var.environment}-${var.region}-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.private_subnet_ids
  security_groups    = [aws_security_group.nlb_sg[0].id]

  tags = {
    Name = "xelta-${var.environment}-backend-nlb"
  }
}

resource "aws_lb_target_group" "backend_tcp" {
  count       = var.enable_xelta ? 1 : 0
  name_prefix = "xl-b-"
  port        = 5000
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "backend_tcp" {
  count             = var.enable_xelta ? 1 : 0
  load_balancer_arn = aws_lb.backend_nlb[0].arn
  port              = 8080
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tcp[0].arn
  }
}

# --- Security Groups ---
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "alb_sg" {
  count       = var.enable_xelta ? 1 : 0
  name        = "xelta-${var.environment}-${var.region}-alb"
  description = "Allow HTTP traffic from VPC (for CDN)"
  vpc_id      = var.vpc_id

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

resource "aws_security_group" "nlb_sg" {
  count       = var.enable_xelta ? 1 : 0
  name        = "xelta-${var.environment}-${var.region}-nlb"
  description = "Allow TCP traffic from VPC (for WSS API GW)"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 8080
    to_port   = 8080
    protocol  = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_service" {
  count       = var.enable_xelta ? 1 : 0
  name        = "xelta-${var.environment}-${var.region}-ecs-service"
  description = "Allow traffic ONLY from the LBs"
  vpc_id      = var.vpc_id

  # Allow traffic from ALB on port 3000
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg[0].id]
  }

  # Allow traffic from NLB on port 5000
  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.nlb_sg[0].id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
