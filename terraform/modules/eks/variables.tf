variable "project_name" {
  description = "The name of the project, used for tagging resources."
  type        = string
}

variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the EKS cluster will be deployed."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of IDs of private subnets for the EKS nodes."
  type        = list(string)
}

variable "eks_cluster_version" {
  description = "The version of the EKS cluster."
  type        = string
}

variable "eks_instance_types" {
  description = "The instance types for the EKS nodes."
  type        = list(string)
}

variable "eks_min_nodes" {
  description = "The minimum number of EKS nodes."
  type        = number
}

variable "eks_max_nodes" {
  description = "The maximum number of EKS nodes."
  type        = number
}