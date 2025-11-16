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

  ecs_cluster_id                = var.shared_cluster_id
  ecs_cluster_name              = var.shared_cluster_name
  ecs_task_execution_role_arn   = aws_iam_role.ecs_task_execution[0].arn
  private_subnet_ids            = var.private_subnet_ids
  ecs_service_security_group_id = aws_security_group.ecs_service[0].id
  target_group_arn              = aws_lb_target_group.frontend[0].arn
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

  ecs_cluster_id                = var.shared_cluster_id
  ecs_cluster_name              = var.shared_cluster_name
  ecs_task_execution_role_arn   = aws_iam_role.ecs_task_execution[0].arn
  private_subnet_ids            = var.private_subnet_ids
  ecs_service_security_group_id = aws_security_group.ecs_service[0].id
  target_group_arn              = aws_lb_target_group.backend[0].arn
  container_port                = 5000
}

# --- Target Groups ---
resource "aws_lb_target_group" "frontend" {
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

resource "aws_lb_target_group" "backend" {
  count       = var.enable_xelta ? 1 : 0
  name_prefix = "xl-b-"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol = "HTTP"
    path     = "/health"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --- Routing Rules ---
resource "aws_lb_listener_rule" "frontend_routing" {
  count        = var.enable_xelta ? 1 : 0
  listener_arn = var.shared_listener_arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend[0].arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
  priority = 100
}

resource "aws_lb_listener_rule" "backend_routing" {
  count        = var.enable_xelta ? 1 : 0
  listener_arn = var.shared_listener_arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend[0].arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
  priority = 1
}

# --- Security Group ---
resource "aws_security_group" "ecs_service" {
  count       = var.enable_xelta ? 1 : 0
  name        = "xelta-${var.environment}-${var.region}-ecs-service"
  description = "Allow traffic from the ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [var.shared_alb_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
