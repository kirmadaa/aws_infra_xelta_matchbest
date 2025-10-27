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
  "us-east-1"    = "811259913050.dkr.ecr.ap-south-1.amazonaws.com/xelta/frontend:us-east-1-ca15a916ed6ee7c652a8ffadecb40992c15b5288"
  "eu-central-1" = "811259913050.dkr.ecr.ap-south-1.amazonaws.com/xelta/frontend:eu-central-1-ca15a916ed6ee7c652a8ffadecb40992c15b5288"
  "ap-south-1"   = "811259913050.dkr.ecr.ap-south-1.amazonaws.com/xelta/frontend:ap-south-1-ca15a916ed6ee7c652a8ffadecb40992c15b5288"
}
backend_images = {
  "us-east-1"    = "811259913050.dkr.ecr.ap-south-1.amazonaws.com/xelta/backend:us-east-1-1be06a6810157808b4edce4376f37ec738d63cb9"
  "eu-central-1" = "811259913050.dkr.ecr.ap-south-1.amazonaws.com/xelta/backend:eu-central-1-1be06a6810157808b4edce4376f37ec738d63cb9"
  "ap-south-1"   = "811259913050.dkr.ecr.ap-south-1.amazonaws.com/xelta/backend:ap-south-1-1be06a6810157808b4edce4376f37ec738d63cb9"
}

# --- ADDED FOR CORS ---
# You can now control these values here
api_gateway_cors_origins = [
  "https://xelta.ai",
  "https://d2cr8lfg6yh01x.cloudfront.net"
]
api_gateway_cors_methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
api_gateway_cors_headers = ["Content-Type", "Authorization"]
