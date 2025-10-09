variable "environment" {
  description = "The deployment environment (e.g., 'dev', 'prod')."
  type        = string
}

variable "aws_region" {
  description = "The AWS region to deploy the infrastructure in."
  type        = string
}

variable "domain_name" {
  description = "The main domain for this environment."
  type        = string
}


variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
}

variable "eks_cluster_version" {
  description = "The Kubernetes version for the EKS cluster."
  type        = string
}

variable "eks_instance_types" {
  description = "The EC2 instance types for the EKS worker nodes."
  type        = list(string)
}

variable "eks_min_nodes" {
  description = "The minimum number of EKS worker nodes."
  type        = number
}

variable "eks_max_nodes" {
  description = "The maximum number of EKS worker nodes."
  type        = number
}

variable "db_skip_final_snapshot" {
  description = "Whether to skip the final DB snapshot on deletion."
  type        = bool
}

variable "aurora_instance_class" {
  description = "The instance class for the Aurora PostgreSQL cluster."
  type        = string
}


variable "redis_node_type" {
  description = "The node type for the ElastiCache for Redis cluster."
  type        = string
}

variable "redis_node_count" {
  description = "The number of nodes for the ElastiCache for Redis cluster."
  type        = number
}
