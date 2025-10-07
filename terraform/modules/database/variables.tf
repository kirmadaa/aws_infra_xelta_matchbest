variable "project_name" { type = string }
variable "vpc_id" { type = string }
variable "database_subnet_ids" { type = list(string) }
variable "eks_node_security_group_id" { type = string }
variable "db_skip_final_snapshot" { type = bool }

variable "aurora_instance_class" { type = string }
variable "docdb_instance_class" { type = string }
variable "redis_node_type" { type = string }
variable "redis_node_count" { type = number }