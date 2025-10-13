# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "xelta-${var.environment}-${var.region}"
}

# IAM Role for ECS Task Execution (permissions to pull ECR images, write logs)
resource "aws_iam_role" "ecs_task_execution" {
  name = "xelta-${var.environment}-${var.region}-ecs-task-execution-role"

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

# IAM Role for the ECS Task itself (permissions for your application code)
resource "aws_iam_role" "ecs_task" {
  name = "xelta-${var.environment}-${var.region}-ecs-task-role"

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

# ECS Task Definition
resource "aws_ecs_task_definition" "main" {
  family                   = "xelta-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "myapp"
      image     = "nginx:1.23.4-alpine"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/xelta-${var.environment}"
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# CloudWatch Log Group for the ECS service
resource "aws_cloudwatch_log_group" "ecs_service" {
  name              = "/ecs/xelta-${var.environment}"
  retention_in_days = 30

  tags = {
    Name        = "xelta-${var.environment}-ecs-logs-${var.region}"
    Environment = var.environment
  }
}

# Security Groups (NLB and ECS Service)
resource "aws_security_group" "nlb" {
  name        = "xelta-${var.environment}-${var.region}-nlb"
  description = "Allow traffic to NLB from within the VPC"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
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
  name        = "xelta-${var.environment}-${var.region}-ecs-service"
  description = "Allow traffic ONLY from the NLB"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.nlb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Network Load Balancer and Listener
resource "aws_lb" "nlb" {
  name               = "xelta-${var.environment}-${var.region}-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.private_subnet_ids
  security_groups    = [aws_security_group.nlb.id]
}

resource "aws_lb_target_group" "main" {
  name        = "xelta-${var.environment}-${var.region}-tg"
  port        = 80
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol            = "HTTP"
    path                = "/health"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
  }
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# ECS Service
resource "aws_ecs_service" "main" {
  name            = "xelta-${var.environment}-${var.region}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  launch_type     = "FARGATE"
  desired_count   = 2 # Initial number of tasks

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.ecs_service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "myapp"
    container_port   = 80
  }

  # Prevent Terraform from replacing the service on desired_count changes
  lifecycle {
    ignore_changes = [desired_count]
  }
}

# --- AUTOSCALING CONFIGURATION ---

# Define the scalable target (our ECS service's task count)
resource "aws_appautoscaling_target" "ecs_service" {
  max_capacity       = 10 # Maximum number of tasks
  min_capacity       = 2  # Minimum number of tasks
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Scaling Policy: Scale-out (add containers) on high CPU
resource "aws_appautoscaling_policy" "scale_out_cpu" {
  name               = "xelta-${var.environment}-scale-out-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 75 # Target 75% CPU utilization
    scale_in_cooldown  = 300 # Cooldown period before scaling in (seconds)
    scale_out_cooldown = 60  # Cooldown period before scaling out again (seconds)
  }
}

# Scaling Policy: Scale-out (add containers) on high Memory
resource "aws_appautoscaling_policy" "scale_out_memory" {
  name               = "xelta-${var.environment}-scale-out-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 75 # Target 75% Memory utilization
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}