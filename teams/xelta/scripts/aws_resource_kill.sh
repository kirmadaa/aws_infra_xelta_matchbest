#!/bin/bash

# WARNING: This script permanently deletes AWS resources and is irreversible.
# Use with extreme caution. It is highly recommended to back up all data first.

# Configuration
PROJECT_TAG_KEY="Project"
PROJECT_TAG_VALUE="xelta"
REGIONS=("us-east-1" "eu-central-1" "ap-south-1") # Add all regions where resources are deployed

# Confirmation prompt
echo "This script will find and delete all resources tagged with '$PROJECT_TAG_KEY=$PROJECT_TAG_VALUE' in the following regions: ${REGIONS[*]}"
read -p "This action is irreversible. Are you sure you want to proceed? (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
  echo "Deletion cancelled."
  exit 0
fi

# Find and delete resources in each region
for region in "${REGIONS[@]}"; do
  echo "--- Processing region: $region ---"
  
  # Get a list of all resource ARNs with the specified tag
  resources=$(aws resourcegroupstaggingapi get-resources --region "$region" \
    --tag-filters "Key=$PROJECT_TAG_KEY,Values=$PROJECT_TAG_VALUE" \
    --query 'ResourceTagMappingList[].ResourceARN' --output json)

  if [[ -z "$resources" || $(echo "$resources" | jq 'length') -eq 0 ]]; then
    echo "No resources found in $region with the specified tag."
    continue
  fi
  
  echo "Found the following resources to delete in $region:"
  echo "$resources" | jq -r '.[]'

  # Note: The deletion logic would be complex here, as each resource type
  # requires a different 'delete' command (e.g., 'aws ec2 terminate-instances',
  # 'aws rds delete-db-instance', 'aws s3api delete-bucket').
  # A fully automated script would need to parse the ARN to determine the
  # service and then call the correct deletion command.
  
  echo "Manual deletion is recommended for resources found by the script to avoid errors."
  echo "Example command to get resource details:"
  echo "aws resourcegroupstaggingapi get-resources --region $region --tag-filters \"Key=$PROJECT_TAG_KEY,Values=$PROJECT_TAG_VALUE\""
  
done

echo "--- Script finished ---"
