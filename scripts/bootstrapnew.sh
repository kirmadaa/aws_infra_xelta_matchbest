#!/bin/bash
set -e

# Bootstrap script for xelta.ai infrastructure deployment
# Usage: ./bootstrap.sh [dev|uat|prod]

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "  xelta.ai Infrastructure Bootstrap"
echo "  Environment: $ENVIRONMENT"
echo "=========================================="
echo ""

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|uat|prod)$ ]]; then
  echo "Error: Environment must be dev, uat, or prod"
  exit 1
fi

# Check prerequisites
echo "[1/6] Checking prerequisites..."
command -v terraform >/dev/null 2>&1 || { echo "Error: terraform not found"; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "Error: aws CLI not found"; exit 1; }

# Verify AWS credentials
aws sts get-caller-identity >/dev/null 2>&1 || { echo "Error: AWS credentials not configured"; exit 1; }
echo "✓ Prerequisites OK"
echo ""

# Change to Terraform directory
cd "$TERRAFORM_DIR"

# Initialize Terraform
echo "[2/6] Initializing Terraform..."
terraform init -upgrade -backend-config="environments/$ENVIRONMENT/$ENVIRONMENT.tfbackend"
echo "✓ Terraform initialized"
echo ""

# Create/select workspace
echo "[3/6] Configuring workspace: $ENVIRONMENT..."
if terraform workspace list | grep -q "$ENVIRONMENT"; then
  terraform workspace select "$ENVIRONMENT"
  echo "✓ Selected existing workspace: $ENVIRONMENT"
else
  terraform workspace new "$ENVIRONMENT"
  echo "✓ Created new workspace: $ENVIRONMENT"
fi
echo ""

# Validate configuration
echo "[4/6] Validating Terraform configuration..."
terraform validate
echo "✓ Configuration valid"
echo ""

# Plan infrastructure
echo "[5/6] Planning infrastructure changes..."
terraform plan \
  -var-file="environments/$ENVIRONMENT/variables.tfvars" \
  -out="$ENVIRONMENT.tfplan"
echo "✓ Plan saved to $ENVIRONMENT.tfplan"
echo ""

# Prompt for apply
echo "[6/6] Ready to apply infrastructure changes"
echo ""
echo "Review the plan above carefully."
read -p "Do you want to apply these changes? (yes/no): " CONFIRM

if [[ "$CONFIRM" == "yes" ]]; then
  echo ""
  echo "Applying infrastructure changes..."
  echo "This will take approximately 25-35 minutes..."
  echo ""

  terraform apply "$ENVIRONMENT.tfplan"

  echo ""
  echo "=========================================="
  echo "✓ Infrastructure deployment complete!"
  echo "=========================================="
  echo ""

  # Display all necessary outputs for the developers
  echo "--- Developer Endpoints & Resources ---"
  echo ""
  echo "Global Application Endpoint (Primary):"
  echo "  CloudFront Domain: $(terraform output -raw cdn_domain_name)"
  echo ""

  echo "Regional API Gateway Endpoints (For testing or region-specific tasks):"
  echo "  us-east-1:    $(terraform output -raw api_gateway_endpoint_us_east_1)"
  echo "  eu-central-1: $(terraform output -raw api_gateway_endpoint_eu_central_1)"
  echo "  ap-south-1:   $(terraform output -raw api_gateway_endpoint_ap_south_1)"
  echo ""

  echo "Regional SQS Queue URLs (For asynchronous jobs):"
  echo "  us-east-1:    $(terraform output -raw sqs_queue_url_us_east_1)"
  echo "  eu-central-1: $(terraform output -raw sqs_queue_url_eu_central_1)"
  echo "  ap-south-1:   $(terraform output -raw sqs_queue_url_ap_south_1)"
  echo ""

  echo "Regional Redis Endpoints (For caching):"
  echo "  us-east-1:    $(terraform output -raw redis_endpoint_us_east_1)"
  echo "  eu-central-1: $(terraform output -raw redis_endpoint_eu_central_1)"
  echo "  ap-south-1:   $(terraform output -raw redis_endpoint_ap_south_1)"
  echo ""

  echo "Secrets & S3 Buckets:"
  echo "  - DB credentials are in AWS Secrets Manager: 'xelta-$ENVIRONMENT-db-credentials'"
  echo "  - Job outputs S3 bucket name: 'xelta-outputs-$ENVIRONMENT'"
  echo ""

  echo "--- Next Steps ---"
  echo "1. Share the above endpoints and resource names with the development team."
  echo "2. Ensure applications are configured to use the AWS SDK to fetch secrets at runtime."
  echo "3. Verify application health through the CloudFront domain."
  echo ""
else
  echo "Deployment cancelled."
  rm -f "$ENVIRONMENT.tfplan"
  exit 0
fi