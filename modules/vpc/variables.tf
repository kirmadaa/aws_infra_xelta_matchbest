variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway (cost optimization) vs one per AZ (HA)"
  type        = bool
  default     = false # Use one NAT per AZ for HA (higher cost)
}

variable "enable_ec2_nat_instance" {
  description = "Use a t4g.nano EC2 instance as a NAT device instead of the managed NAT Gateway."
  type        = bool
  default     = false
}