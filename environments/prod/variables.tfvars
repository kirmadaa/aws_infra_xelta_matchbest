environment = "prod"
domain_name = "xelta.ai"

regions = ["us-east-1", "eu-central-1", "ap-south-1"]

vpc_cidr_blocks = {
  "us-east-1"    = "10.20.0.0/16"
  "eu-central-1" = "10.21.0.0/16"
  "ap-south-1"   = "10.22.0.0/16"
}


# Redis Configuration (Production)
redis_node_type       = "cache.r6g.xlarge"
redis_num_cache_nodes = 3
enable_redis          = true

# Service Images (TODO: Update with actual ECR URIs)
frontend_images = {
  "us-east-1"    = "nginx:latest"
  "eu-central-1" = "nginx:latest"
  "ap-south-1"   = "nginx:latest"
}

backend_images = {
  "us-east-1"    = "nginx:latest"
  "eu-central-1" = "nginx:latest"
  "ap-south-1"   = "nginx:latest"
}

agent_images = {
  "us-east-1"    = "nginx:latest"
  "eu-central-1" = "nginx:latest"
  "ap-south-1"   = "nginx:latest"
}

photogpt_images = {
  "us-east-1"    = "nginx:latest"
  "eu-central-1" = "nginx:latest"
  "ap-south-1"   = "nginx:latest"
}

photolab_images = {
  "us-east-1"    = "nginx:latest"
  "eu-central-1" = "nginx:latest"
  "ap-south-1"   = "nginx:latest"
}

homedesign_images = {
  "us-east-1"    = "nginx:latest"
  "eu-central-1" = "nginx:latest"
  "ap-south-1"   = "nginx:latest"
}

comicflow_images = {
  "us-east-1"    = "nginx:latest"
  "eu-central-1" = "nginx:latest"
  "ap-south-1"   = "nginx:latest"
}

cmsb_images = {
  "us-east-1"    = "nginx:latest"
  "eu-central-1" = "nginx:latest"
  "ap-south-1"   = "nginx:latest"
}