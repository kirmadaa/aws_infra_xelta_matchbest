environment = "uat"
domain_name = "xelta.ai"

regions = ["us-east-1", "eu-central-1", "ap-south-1"]

vpc_cidr_blocks = {
  "us-east-1"    = "10.10.0.0/16"
  "eu-central-1" = "10.11.0.0/16"
  "ap-south-1"   = "10.12.0.0/16"
}


# Redis Configuration (UAT)
redis_node_type       = "cache.r6g.large"
redis_num_cache_nodes = 2
enable_redis          = true