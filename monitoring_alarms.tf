
 resource "aws_cloudwatch_metric_alarm" "backend_cpu_utilization_us_east_1" {
  provider                  = aws.us_east_1
  alarm_name                = "xelta-backend-cpu-utilization-us-east-1"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "2"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/ECS"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = "80"
  alarm_description         = "Backend CPU utilization is high in us-east-1"
  dimensions = {
    ClusterName = module.ecs_service_us_east_1.cluster_name
    ServiceName = module.ecs_service_us_east_1.backend_service_name
  }
 }

 resource "aws_cloudwatch_metric_alarm" "backend_5xx_errors_us_east_1" {
  provider                  = aws.us_east_1
  alarm_name                = "xelta-backend-5xx-errors-us-east-1"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "1"
  metric_name               = "HTTPCode_Target_5XX_Count"
  namespace                 = "AWS/ApplicationELB"
  period                    = "60"
  statistic                 = "Sum"
  threshold                 = "10"
  alarm_description         = "Backend is returning 5xx errors in us-east-1"
  dimensions = {
    TargetGroup = module.ecs_service_us_east_1.backend_target_group_arn
  }
 }
  resource "aws_cloudwatch_metric_alarm" "backend_cpu_utilization_eu_central_1" {
  provider                  = aws.eu_central_1
  alarm_name                = "xelta-backend-cpu-utilization-eu-central-1"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "2"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/ECS"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = "80"
  alarm_description         = "Backend CPU utilization is high in eu-central-1"
  dimensions = {
    ClusterName = module.ecs_service_eu_central_1.cluster_name
    ServiceName = module.ecs_service_eu_central_1.backend_service_name
  }
 }

 resource "aws_cloudwatch_metric_alarm" "backend_5xx_errors_eu_central_1" {
  provider                  = aws.eu_central_1
  alarm_name                = "xelta-backend-5xx-errors-eu-central-1"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "1"
  metric_name               = "HTTPCode_Target_5XX_Count"
  namespace                 = "AWS/ApplicationELB"
  period                    = "60"
  statistic                 = "Sum"
  threshold                 = "10"
  alarm_description         = "Backend is returning 5xx errors in eu-central-1"
  dimensions = {
    TargetGroup = module.ecs_service_eu_central_1.backend_target_group_arn
  }
 }
  resource "aws_cloudwatch_metric_alarm" "backend_cpu_utilization_ap_south_1" {
  provider                  = aws.ap_south_1
  alarm_name                = "xelta-backend-cpu-utilization-ap-south-1"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "2"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/ECS"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = "80"
  alarm_description         = "Backend CPU utilization is high in ap-south-1"
  dimensions = {
    ClusterName = module.ecs_service_ap_south_1.cluster_name
    ServiceName = module.ecs_service_ap_south_1.backend_service_name
  }
 }

 resource "aws_cloudwatch_metric_alarm" "backend_5xx_errors_ap_south_1" {
  provider                  = aws.ap_south_1
  alarm_name                = "xelta-backend-5xx-errors-ap-south-1"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "1"
  metric_name               = "HTTPCode_Target_5XX_Count"
  namespace                 = "AWS/ApplicationELB"
  period                    = "60"
  statistic                 = "Sum"
  threshold                 = "10"
  alarm_description         = "Backend is returning 5xx errors in ap-south-1"
  dimensions = {
    TargetGroup = module.ecs_service_ap_south_1.backend_target_group_arn
  }
 }
