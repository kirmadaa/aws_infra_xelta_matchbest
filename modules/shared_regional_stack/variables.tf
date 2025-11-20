variable "environment" {
  description = "The deployment environment (dev, prod, uat)"
  type        = string
}

variable "region" {
  description = "The AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Whether to use a single NAT gateway"
  type        = bool
  default     = false
}

variable "enable_ec2_nat_instance" {
  description = "Enable EC2 NAT instance instead of NAT Gateway"
  type        = bool
  default     = false
}
