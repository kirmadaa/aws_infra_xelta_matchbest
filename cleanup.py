#!/bin/bash
# Script to clean up existing resources that are causing conflicts
# Run this BEFORE applying the fixed Terraform code

set -e

ENVIRONMENT="dev"
REGIONS=("us-east-1" "eu-central-1" "ap-south-1")

echo "================================================"
echo "Xelta Infrastructure Cleanup Script"
echo "Environment: $ENVIRONMENT"
echo "================================================"
echo ""

# Confirmation
read -p "This will delete existing conflicting resources. Continue? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Cancelled."
    exit 0
fi

# Function to delete secrets scheduled for deletion
delete_secrets() {
    local region=$1
    echo "Checking Secrets Manager in $region..."
    
    # Force delete secrets that are scheduled for deletion
    secret_name="xelta-${ENVIRONMENT}-db-credentials"
    
    if aws secretsmanager describe-secret --secret-id "$secret_name" --region "$region" &>/dev/null; then
        echo "  Forcing immediate deletion of $secret_name..."
        aws secretsmanager delete-secret \
            --secret-id "$secret_name" \
            --force-delete-without-recovery \
            --region "$region" 2>/dev/null || echo "  Secret already scheduled for deletion"
    else
        echo "  Secret $secret_name not found or already deleted"
    fi
}

# Function to delete CloudWatch log groups
delete_log_groups() {
    local region=$1
    echo "Checking CloudWatch Log Groups in $region..."
    
    log_group="/aws/vpc/xelta-${ENVIRONMENT}-${region}"
    
    if aws logs describe-log-groups --log-group-name-prefix "$log_group" --region "$region" --query "logGroups[?logGroupName=='$log_group']" --output text | grep -q "$log_group"; then
        echo "  Deleting log group $log_group..."
        aws logs delete-log-group --log-group-name "$log_group" --region "$region" || echo "  Failed to delete, may not exist"
    else
        echo "  Log group $log_group not found"
    fi
}

# Process each region
for region in "${REGIONS[@]}"; do
    echo ""
    echo "--- Processing Region: $region ---"
    delete_secrets "$region"
    delete_log_groups "$region"
done

echo ""
echo "================================================"
echo "Cleanup Complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo "1. Wait 30 seconds for deletions to propagate"
echo "2. Run 'terraform init' to reinitialize"
echo "3. Run 'terraform plan' to verify the fixes"
echo "4. Run 'terraform apply' to deploy"
echo ""

# Optional: Wait for propagation
echo "Waiting 30 seconds for AWS to process deletions..."
sleep 30
echo "Done! You can now proceed with terraform apply."
