# environments/dev/variables.tfvars

environment = "dev"

alarm_sns_topic_arn = "arn:aws:sns:us-east-1:123456789012:DefaultAlarms" # Replace with a valid ARN

regional_configs = {
  us-east-1 = {
    region             = "us-east-1"
    availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
    vpc_cidr           = "10.0.0.0/16"
    frontend_image     = "nginx:latest"
    backend_image      = "nginx:latest"
    single_nat_gateway = true
  },
  eu-central-1 = {
    region             = "eu-central-1"
    availability_zones = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
    vpc_cidr           = "10.1.0.0/16"
    frontend_image     = "nginx:latest"
    backend_image      = "nginx:latest"
    single_nat_gateway = true
  }
}
