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
enable_ec2_nat_instance = true

# Container Images
frontend_images = {
  "us-east-1"    = "811259913050.dkr.ecr.us-east-1.amazonaws.com/xelta/frontend:us-east-1-c9a5e65dab94cb0fd1bccdae838e00f86ae0f63e"
  "eu-central-1" = "811259913050.dkr.ecr.eu-central-1.amazonaws.com/xelta/frontend:eu-central-1-c9a5e65dab94cb0fd1bccdae838e00f86ae0f63e"
  "ap-south-1"   = "811259913050.dkr.ecr.ap-south-1.amazonaws.com/xelta/frontend:ap-south-1-2c9a5e65dab94cb0fd1bccdae838e00f86ae0f63e"
}
backend_images = {
  "us-east-1"    = "811259913050.dkr.ecr.us-east-1.amazonaws.com/xelta/backend:us-east-1-5f1ddfe851bff7a5cab7dcdc82a62c0418f0c0e5"
  "eu-central-1" = "811259913050.dkr.ecr.eu-central-1.amazonaws.com/xelta/backend:eu-central-1-5f1ddfe851bff7a5cab7dcdc82a62c0418f0c0e5"
  "ap-south-1"   = "811259913050.dkr.ecr.ap-south-1.amazonaws.com/xelta/backend:ap-south-1-5f1ddfe851bff7a5cab7dcdc82a62c0418f0c0e5"
}

# --- ADDED FOR CORS ---
# You can now control these values here
api_gateway_cors_origins = [
  "https://xelta.ai",
  "https://d3w2zagi373ltj.cloudfront.net"
]
api_gateway_cors_methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
api_gateway_cors_headers = ["Content-Type", "Authorization"]
