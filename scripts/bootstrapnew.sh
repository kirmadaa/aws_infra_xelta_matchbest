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

  # Display outputs
  echo "Cluster configuration commands:"
  terraform output -raw kubectl_config_commands
  echo ""

  echo "ALB Endpoints:"
  echo "  us-east-1:    $(terraform output -raw alb_dns_us_east_1)"
  echo "  eu-central-1: $(terraform output -raw alb_dns_eu_central_1)"
  echo "  ap-south-1:   $(terraform output -raw alb_dns_ap_south_1)"
  echo ""

  echo "Next steps:"
  echo "1. Configure kubectl using the commands above"
  echo "2. Install AWS Load Balancer Controller in each cluster"
  echo "3. Deploy application manifests"
  echo "4. Verify Route53 DNS propagation (may take 5-10 minutes)"
  echo ""
else
  echo "Deployment cancelled."
  rm -f "$ENVIRONMENT.tfplan"
  exit 0
fi
