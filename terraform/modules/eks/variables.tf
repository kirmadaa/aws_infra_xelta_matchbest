variable "project_name" { type = string }
variable "aws_region" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "eks_cluster_version" { type = string }
variable "eks_instance_types" { type = list(string) }
variable "eks_min_nodes" { type = number }
variable "eks_max_nodes" { type = number }

variable "ec2_key_name" {
  type        = string
  description = "EC2 key name for SSH access to nodes. Leave empty for no access."
  default     = ""
}