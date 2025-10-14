# modules/monitoring/main.tf

# CloudWatch dashboard for monitoring
resource "aws_cloudwatch_dashboard" "performance" {
  dashboard_name = "xelta-${var.environment}-performance"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", var.backend_ecs_service_name],
            ["AWS/ECS", "MemoryUtilization", "ServiceName", var.backend_ecs_service_name],
            ["AWS/ECS", "CPUUtilization", "ServiceName", var.frontend_ecs_service_name],
            ["AWS/ECS", "MemoryUtilization", "ServiceName", var.frontend_ecs_service_name],
            ["AWS/NetworkELB", "HealthyHostCount", "LoadBalancer", var.nlb_arn_suffix],
            ["AWS/NetworkELB", "UnHealthyHostCount", "LoadBalancer", var.nlb_arn_suffix]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "Performance Metrics"
        }
      }
    ]
  })
}

# Alarms for unhealthy hosts
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "xelta-${var.environment}-${var.region}-unhealthy-hosts"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/NetworkELB"
  period              = "120"
  statistic           = "Maximum"
  threshold           = "1"
  alarm_description   = "This metric monitors for unhealthy NLB targets"

  dimensions = {
    LoadBalancer = var.nlb_arn_suffix
  }
}
