environment = "dev"
domain_name = "xelta.ai"

vpc_cidr_blocks = {
  "us-east-1"    = "10.0.0.0/16"
  "eu-central-1" = "10.1.0.0/16"
  "ap-south-1"   = "10.2.0.0/16"
}

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

# Deploy Xelta ONLY to US and EU. Kill it in AP.
xelta_region_config = {
  "us-east-1"    = true
  "eu-central-1" = true
  "ap-south-1"   = false
}
