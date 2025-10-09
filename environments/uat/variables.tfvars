environment = "uat"
domain_name = "xelta.ai"

regions = ["us-east-1", "eu-central-1", "ap-south-1"]

vpc_cidr_blocks = {
  "us-east-1"    = "10.10.0.0/16"
  "eu-central-1" = "10.11.0.0/16"
  "ap-south-1"   = "10.12.0.0/16"
}

# EKS Configuration (UAT-sized)
eks_version             = "1.28"
eks_node_instance_types = ["t3.large"]
eks_node_desired_size   = 3
eks_node_min_size       = 3
eks_node_max_size       = 6

# Aurora Configuration (UAT)
aurora_instance_class = "db.r6g.large"
aurora_instance_count = 2
enable_aurora         = true

# Redis Configuration (UAT)
redis_node_type       = "cache.r6g.large"
redis_num_cache_nodes = 2
enable_redis          = true