environment = "dev"
domain_name = "xelta.ai"

# --- Application Deployment ---
# Replace these with your actual Docker image URIs
#backend_image  = "your-registry/your-backend-app:latest"
#frontend_image = "your-registry/your-frontend-app:latest"

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
