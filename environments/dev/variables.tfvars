environment = "dev"
domain_name = "xelta.ai"

# Multi-region deployment
regions = ["us-east-1", "eu-central-1", "ap-south-1"]

vpc_cidr_blocks = {
  "us-east-1"    = "10.0.0.0/16"
  "eu-central-1" = "10.1.0.0/16"
  "ap-south-1"   = "10.2.0.0/16"
}


# Redis Configuration (minimal for dev)
redis_node_type       = "cache.t3.micro"
redis_num_cache_nodes = 1
enable_redis          = true

# Container Images
frontend_images = {
  "us-east-1"    = "811259913050.dkr.ecr.ap-south-1.amazonaws.com/xelta/frontend:us-east-1-0980ebb0cf6b389f955ad37d24a2fc3e368bd26e"
  "eu-central-1" = "811259913050.dkr.ecr.ap-south-1.amazonaws.com/xelta/frontend:eu-central-1-0980ebb0cf6b389f955ad37d24a2fc3e368bd26e"
  "ap-south-1"   = "811259913050.dkr.ecr.ap-south-1.amazonaws.com/xelta/frontend:ap-south-1-0980ebb0cf6b389f955ad37d24a2fc3e368bd26e"
}
backend_images = {
  "us-east-1"    = "811259913050.dkr.ecr.ap-south-1.amazonaws.com/xelta/backend:us-east-1-7e6c79b64918d2b380351703a50c24ba4be07d24"
  "eu-central-1" = "811259913050.dkr.ecr.ap-south-1.amazonaws.com/xelta/backend:eu-central-1-7e6c79b64918d2b380351703a50c24ba4be07d24"
  "ap-south-1"   = "811259913050.dkr.ecr.ap-south-1.amazonaws.com/xelta/backend:ap-south-1-7e6c79b64918d2b380351703a50c24ba4be07d24"
}

