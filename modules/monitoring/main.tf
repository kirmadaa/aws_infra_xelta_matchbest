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
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix]
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

# Alarms for performance degradation
resource "aws_cloudwatch_metric_alarm" "high_response_time" {
  alarm_name          = "xelta-${var.environment}-${var.region}-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "120"
  statistic           = "Average"
  threshold           = "1.0"  # 1 second threshold
  alarm_description   = "This metric monitors ALB response time"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
}
