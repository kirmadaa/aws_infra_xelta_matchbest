variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where endpoints will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for interface endpoints"
  type        = list(string)
}

variable "private_route_table_ids" {
  description = "List of private route table IDs for gateway endpoints"
  type        = list(string)
}

variable "enable_s3_endpoint" {
  description = "Enable S3 Gateway Endpoint"
  type        = bool
  default     = true
}

variable "enable_dynamodb_endpoint" {
  description = "Enable DynamoDB Gateway Endpoint"
  type        = bool
  default     = true
}

variable "enable_ecr_endpoints" {
  description = "Enable ECR API and Docker Interface Endpoints"
  type        = bool
  default     = true
}

variable "enable_secrets_endpoint" {
  description = "Enable Secrets Manager Interface Endpoint"
  type        = bool
  default     = true
}
