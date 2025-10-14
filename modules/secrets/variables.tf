variable "environment" {
  description = "Environment name"
  type        = string
}

variable "replica_regions" {
  description = "A list of AWS regions to replicate the secret to."
  type        = list(string)
  default     = []
}
