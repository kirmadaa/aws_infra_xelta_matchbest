environment = "dev"
domain_name = "xelta.ai"

# Multi-region deployment
regions = ["us-east-1", "eu-central-1", "ap-south-1"]

vpc_cidr_blocks = {
  "us-east-1"    = "10.0.0.0/16"
  "eu-central-1" = "10.1.0.0/16"
  "ap-south-1"   = "10.2.0.0/16"
}

# EKS Configuration (dev-sized)
eks_version             = "1.28"
eks_node_instance_types = ["t3.medium"]
eks_node_desired_size   = 2
eks_node_min_size       = 2
eks_node_max_size       = 2

# Aurora Configuration (minimal for dev)
aurora_instance_class = "db.t3.small"
aurora_instance_count = 2 # 1 writer + 1 reader
enable_aurora         = true

# Redis Configuration (minimal for dev)
redis_node_type       = "cache.t3.micro"
redis_num_cache_nodes = 1
enable_redis          = true
