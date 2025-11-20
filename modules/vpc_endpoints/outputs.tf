output "s3_endpoint_id" {
  description = "ID of the S3 VPC Endpoint"
  value       = try(aws_vpc_endpoint.s3[0].id, "")
}

output "dynamodb_endpoint_id" {
  description = "ID of the DynamoDB VPC Endpoint"
  value       = try(aws_vpc_endpoint.dynamodb[0].id, "")
}

output "ecr_api_endpoint_id" {
  description = "ID of the ECR API VPC Endpoint"
  value       = try(aws_vpc_endpoint.ecr_api[0].id, "")
}

output "ecr_dkr_endpoint_id" {
  description = "ID of the ECR Docker VPC Endpoint"
  value       = try(aws_vpc_endpoint.ecr_dkr[0].id, "")
}

output "secretsmanager_endpoint_id" {
  description = "ID of the Secrets Manager VPC Endpoint"
  value       = try(aws_vpc_endpoint.secretsmanager[0].id, "")
}

output "logs_endpoint_id" {
  description = "ID of the CloudWatch Logs VPC Endpoint"
  value       = try(aws_vpc_endpoint.logs[0].id, "")
}
