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
command -v terraform >/dev/null 2D&1 || { echo "Error: terraform not found"; exit 1; }
command -v aws >/dev/null 2D&1 || { echo "Error: aws CLI not found"; exit 1; }

# Verify AWS credentials
aws sts get-caller-identity >/dev/null 2D&1 || { echo "Error: AWS credentials not configured"; exit 1; }
echo "✓ Prerequisites OK"
echo ""

# Change to Terraform directory
cd "$TERRAFORM_DIR"

# Initialize Terraform
echo "[2/6] Initializing Terraform..."
terraform init -upgrade
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