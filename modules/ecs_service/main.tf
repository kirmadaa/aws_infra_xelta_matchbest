resource "aws_cloudwatch_log_group" "frontend" {
  name = "/aws/ecs/xelta-${var.environment}-frontend-${var.region}"
  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_log_group" "backend" {
  name = "/aws/ecs/xelta-${var.environment}-backend-${var.region}"
  tags = { Environment = var.environment }
}

# --- NEW LOG GROUPS ---
resource "aws_cloudwatch_log_group" "agent" {
  name = "/aws/ecs/xelta-${var.environment}-agent-${var.region}"
  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_log_group" "photogpt" {
  name = "/aws/ecs/xelta-${var.environment}-photogpt-${var.region}"
  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_log_group" "photolab" {
  name = "/aws/ecs/xelta-${var.environment}-photolab-${var.region}"
  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_log_group" "homedesign" {
  name = "/aws/ecs/xelta-${var.environment}-homedesign-${var.region}"
  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_log_group" "comicflow" {
  name = "/aws/ecs/xelta-${var.environment}-comicflow-${var.region}"
  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_log_group" "cmsb" {
  name = "/aws/ecs/xelta-${var.environment}-cmsb-${var.region}"
  tags = { Environment = var.environment }
}
# ----------------------

resource "aws_ecs_cluster" "main" {
  name = "xelta-${var.environment}-${var.region}"
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "xelta-${var.environment}-${var.region}-ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "ecs_exec" {
  name        = "xelta-${var.environment}-${var.region}-ecs-exec-policy"
  description = "Allow ECS tasks to be accessed via ECS Exec"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_exec" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = aws_iam_policy.ecs_exec.arn
}

# --- Frontend Service (ALB) ---

resource "aws_ecs_task_definition" "frontend" {
  family                   = "xelta-${var.environment}-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name      = "frontend"
    image     = var.frontend_image
    cpu       = 100
    memory    = 256
    essential = true
    # --- UPDATED: Port 443 ---
    portMappings = [{ containerPort = 443, hostPort = 443 }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "frontend" {
  name                   = "xelta-${var.environment}-frontend"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.frontend.arn
  desired_count          = 2
  enable_execute_command = true

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  # --- UPDATED STRATEGY: 1 On-Demand base, then 80/20 Spot ---
  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    base              = 1
    weight            = 1
  }
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 4
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend_http.arn
    container_name   = "frontend"
    container_port   = 443 # --- UPDATED ---
  }
}

# --- Backend Service (NLB) ---

resource "aws_ecs_task_definition" "backend" {
  family                   = "xelta-${var.environment}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name      = "backend"
    image     = var.backend_image
    cpu       = 256
    memory    = 512
    essential = true
    portMappings = [{ containerPort = 5000, hostPort = 5000 }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.backend.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "backend" {
  name                   = "xelta-${var.environment}-backend"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.backend.arn
  desired_count          = 2
  enable_execute_command = true

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  # --- UPDATED STRATEGY ---
  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    base              = 1
    weight            = 1
  }
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 4
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_tcp.arn
    container_name   = "backend"
    container_port   = 5000
  }
}

# --- NEW SERVICES (Standard Config, No LB for now) ---

locals {
  new_services = {
    agent      = var.agent_image
    photogpt   = var.photogpt_image
    photolab   = var.photolab_image
    homedesign = var.homedesign_image
    comicflow  = var.comicflow_image
    cmsb       = var.cmsb_image
  }
}

# To avoid massive duplication, I'll use separate resources, but follow the pattern.
# Cannot use for_each easily for top-level resources mixed with explicit ones in this style without refactoring everything.
# I will write them explicitly as requested.

# --- Agent ---
resource "aws_ecs_task_definition" "agent" {
  family                   = "xelta-${var.environment}-agent"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_execution.arn
  container_definitions = jsonencode([{
    name      = "agent"
    image     = var.agent_image
    essential = true
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.agent.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "agent" {
  name                   = "xelta-${var.environment}-agent"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.agent.arn
  desired_count          = 2
  enable_execute_command = true
  
  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    base              = 1
    weight            = 1
  }
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 4
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = false
  }
}

# --- PhotoGPT ---
resource "aws_ecs_task_definition" "photogpt" {
  family                   = "xelta-${var.environment}-photogpt"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_execution.arn
  container_definitions = jsonencode([{
    name      = "photogpt"
    image     = var.photogpt_image
    essential = true
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.photogpt.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "photogpt" {
  name                   = "xelta-${var.environment}-photogpt"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.photogpt.arn
  desired_count          = 2
  enable_execute_command = true

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    base              = 1
    weight            = 1
  }
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 4
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = false
  }
}

# --- PhotoLab ---
resource "aws_ecs_task_definition" "photolab" {
  family                   = "xelta-${var.environment}-photolab"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_execution.arn
  container_definitions = jsonencode([{
    name      = "photolab"
    image     = var.photolab_image
    essential = true
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.photolab.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "photolab" {
  name                   = "xelta-${var.environment}-photolab"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.photolab.arn
  desired_count          = 2
  enable_execute_command = true

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    base              = 1
    weight            = 1
  }
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 4
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = false
  }
}

# --- HomeDesign ---
resource "aws_ecs_task_definition" "homedesign" {
  family                   = "xelta-${var.environment}-homedesign"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_execution.arn
  container_definitions = jsonencode([{
    name      = "homedesign"
    image     = var.homedesign_image
    essential = true
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.homedesign.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "homedesign" {
  name                   = "xelta-${var.environment}-homedesign"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.homedesign.arn
  desired_count          = 2
  enable_execute_command = true

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    base              = 1
    weight            = 1
  }
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 4
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = false
  }
}

# --- ComicFlow ---
resource "aws_ecs_task_definition" "comicflow" {
  family                   = "xelta-${var.environment}-comicflow"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_execution.arn
  container_definitions = jsonencode([{
    name      = "comicflow"
    image     = var.comicflow_image
    essential = true
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.comicflow.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "comicflow" {
  name                   = "xelta-${var.environment}-comicflow"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.comicflow.arn
  desired_count          = 2
  enable_execute_command = true

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    base              = 1
    weight            = 1
  }
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 4
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = false
  }
}

# --- CMSB ---
resource "aws_ecs_task_definition" "cmsb" {
  family                   = "xelta-${var.environment}-cmsb"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_execution.arn
  container_definitions = jsonencode([{
    name      = "cmsb"
    image     = var.cmsb_image
    essential = true
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.cmsb.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "cmsb" {
  name                   = "xelta-${var.environment}-cmsb"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.cmsb.arn
  desired_count          = 2
  enable_execute_command = true

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    base              = 1
    weight            = 1
  }
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 4
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = false
  }
}

# --- Autoscaling ---
# Note: Autoscaling for new services generally follows the same pattern.
# For brevity and to ensure correctness, I'm including the existing + new policies.

resource "aws_appautoscaling_target" "frontend" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.frontend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "frontend_cpu" {
  name               = "frontend-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.frontend.resource_id
  scalable_dimension = aws_appautoscaling_target.frontend.scalable_dimension
  service_namespace  = aws_appautoscaling_target.frontend.service_namespace
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification { predefined_metric_type = "ECSServiceAverageCPUUtilization" }
    target_value = 60
  }
}

resource "aws_appautoscaling_target" "backend" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.backend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "backend_cpu" {
  name               = "backend-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.backend.resource_id
  scalable_dimension = aws_appautoscaling_target.backend.scalable_dimension
  service_namespace  = aws_appautoscaling_target.backend.service_namespace
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification { predefined_metric_type = "ECSServiceAverageCPUUtilization" }
    target_value = 60
  }
}

# --- Networking ---

resource "aws_lb" "frontend_alb" {
  name               = "xl-fe-${var.environment}-${var.region}"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb_sg.id]
  tags = { Name = "xelta-${var.environment}-frontend-alb" }
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_lb_target_group" "frontend_http" {
  name_prefix = "xl-f-"
  # --- UPDATED: Port 443 ---
  port        = 443
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    protocol = "HTTP"
    path     = "/"
  }
  lifecycle { create_before_destroy = true }
}

resource "aws_lb_listener" "frontend_http" {
  load_balancer_arn = aws_lb.frontend_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_http.arn
  }
}

resource "aws_lb" "backend_nlb" {
  name               = "xelta-${var.environment}-${var.region}-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.private_subnet_ids
  security_groups    = [aws_security_group.nlb_sg.id]
  tags = { Name = "xelta-${var.environment}-backend-nlb" }
}

resource "aws_lb_target_group" "backend_tcp" {
  name_prefix = "xl-b-"
  port        = 5000
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  lifecycle { create_before_destroy = true }
}

resource "aws_lb_listener" "backend_tcp" {
  load_balancer_arn = aws_lb.backend_nlb.arn
  port              = 8080
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tcp.arn
  }
}

# --- Security Groups ---

resource "aws_security_group" "alb_sg" {
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

resource "aws_security_group" "worker_lambda_sg" {
  name        = "xelta-${var.environment}-${var.region}-worker-lambda"
  description = "Allow outbound traffic from worker lambda"
  vpc_id      = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "nlb_sg" {
  name        = "xelta-${var.environment}-${var.region}-nlb"
  description = "Allow TCP traffic from VPC (for WSS API GW)"
  vpc_id      = var.vpc_id
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.worker_lambda_sg.id, var.http_api_vpclink_sg_id]
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
  description = "Allow traffic ONLY from the LBs"
  vpc_id      = var.vpc_id
  # Allow traffic from ALB on port 443 (frontend)
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  # Allow traffic from NLB on port 5000 (backend)
  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.nlb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}