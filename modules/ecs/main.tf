# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "xelta-${var.environment}-cluster-${var.region}"

  tags = {
    Name        = "xelta-${var.environment}-cluster-${var.region}"
    Environment = var.environment
  }
}

# IAM Role for ECS Tasks
resource "aws_iam_role" "task_execution_role" {
  name = "xelta-${var.environment}-ecs-execution-role-${var.region}"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# CloudWatch Log Group for the container
resource "aws_cloudwatch_log_group" "service_logs" {
  name = "/ecs/xelta-${var.environment}-${var.service_name}"
  retention_in_days = 7
}

# ECS Task Definition for a Fargate service
resource "aws_ecs_task_definition" "main" {
  family                   = "xelta-${var.environment}-${var.service_name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"  # 0.25 vCPU
  memory                   = "512"  # 512 MB
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  # task_role_arn can be added here for permissions to other AWS services like S3 or Secrets Manager

  container_definitions = jsonencode([
    {
      name      = var.service_name
      image     = var.container_image
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.service_logs.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# Security Group for the ECS Service
resource "aws_security_group" "service_sg" {
  name        = "xelta-${var.environment}-${var.service_name}-sg"
  description = "Allow traffic to the ECS service"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "xelta-${var.environment}-${var.service_name}-sg"
  }
}

# ECS Service
resource "aws_ecs_service" "main" {
  name            = "xelta-${var.environment}-${var.service_name}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.service_sg.id]
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  depends_on = [aws_iam_role_policy_attachment.ecs_execution_policy]
}
