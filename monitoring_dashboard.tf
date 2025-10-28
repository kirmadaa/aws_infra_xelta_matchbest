
 resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "xelta-main-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", module.ecs_service_us_east_1.cluster_name, "ServiceName", module.ecs_service_us_east_1.backend_service_name],
            [".", ".", "ClusterName", module.ecs_service_eu_central_1.cluster_name, "ServiceName", module.ecs_service_eu_central_1.backend_service_name, { region = "eu-central-1" }],
            [".", ".", "ClusterName", module.ecs_service_ap_south_1.cluster_name, "ServiceName", module.ecs_service_ap_south_1.backend_service_name, { region = "ap-south-1" }]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "Backend CPU Utilization (All Regions)"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "TargetGroup", module.ecs_service_us_east_1.backend_target_group_arn],
            [".", ".", "TargetGroup", module.ecs_service_eu_central_1.backend_target_group_arn, { region = "eu-central-1" }],
            [".", ".", "TargetGroup", module.ecs_service_ap_south_1.backend_target_group_arn, { region = "ap-south-1" }]
          ]
          period = 60
          stat   = "Sum"
          region = "us-east-1"
          title  = "Backend 5xx Errors (All Regions)"
        }
      }
    ]
  })
}
