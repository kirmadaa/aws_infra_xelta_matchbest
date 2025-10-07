variable "project_name" {
  description = "The name of the project, used for tagging resources."
  type        = string
}

variable "environment" {
  description = "The environment name (e.g., 'dev', 'prod')."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the databases will be deployed."
  type        = string
}

variable "database_subnet_ids" {
  description = "List of IDs of database subnets."
  type        = list(string)
}

variable "eks_node_security_group_id" {
  description = "The ID of the security group for the EKS nodes to allow database access."
  type        = string
}

variable "db_skip_final_snapshot" {
  description = "If true, skip creating a final snapshot on cluster deletion."
  type        = bool
}

variable "aurora_instance_class" {
  description = "The instance class for the Aurora PostgreSQL cluster."
  type        = string
}


variable "redis_node_type" {
  description = "The node type for the ElastiCache Redis cluster."
  type        = string
}

variable "redis_node_count" {
  description = "The number of nodes in the ElastiCache Redis cluster."
  type        = number
}
