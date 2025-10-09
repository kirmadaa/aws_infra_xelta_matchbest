environment = "prod"
domain_name = "xelta.ai"

regions = ["us-east-1", "eu-central-1", "ap-south-1"]

vpc_cidr_blocks = {
  "us-east-1"    = "10.20.0.0/16"
  "eu-central-1" = "10.21.0.0/16"
  "ap-south-1"   = "10.22.0.0/16"
}

# EKS Configuration (Production-sized)
eks_version             = "1.28"
eks_node_instance_types = ["m5.xlarge"]
eks_node_desired_size   = 6
eks_node_min_size       = 6
eks_node_max_size       = 12

# Aurora Configuration (Production)
aurora_instance_class = "db.r6g.2xlarge"
aurora_instance_count = 3 # 1 writer + 2 readers
enable_aurora         = true

# Redis Configuration (Production)
redis_node_type       = "cache.r6g.xlarge"
redis_num_cache_nodes = 3
enable_redis          = true