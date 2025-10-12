#!/bin/bash

# WARNING: This script permanently deletes AWS resources and is irreversible.
# It is designed to be run multiple times to handle dependencies.

# --- Configuration ---
PROJECT_TAG_KEY="Project"
PROJECT_TAG_VALUE="xelta"
REGIONS=("us-east-1" "eu-central-1" "ap-south-1")

# --- Deletion Logic ---

delete_resources() {
    local arn=$1
    local region=$2
    local service=$(echo "$arn" | awk -F: '{print $3}')
    local resource_type=$(echo "$arn" | awk -F: '{print $6}' | awk -F/ '{print $1}')
    local resource_id=$(echo "$arn" | awk -F/ '{print $NF}')

    echo "INFO: Found ARN: $arn"
    
    # --- High-Level Services (Delete First) ---
    if [[ "$service" == "eks" && "$resource_type" == "nodegroup" ]]; then
        local cluster_name=$(echo "$arn" | awk -F/ '{print $(NF-2)}')
        echo "--> ACTION: Deleting EKS Node Group: $resource_id in cluster $cluster_name"
        aws eks delete-nodegroup --cluster-name "$cluster_name" --nodegroup-name "$resource_id" --region "$region"
    elif [[ "$service" == "eks" && "$resource_type" == "cluster" ]]; then
        echo "--> ACTION: Deleting EKS Cluster: $resource_id"
        aws eks delete-cluster --name "$resource_id" --region "$region"
    elif [[ "$service" == "elasticloadbalancing" && "$resource_type" == "loadbalancer" ]]; then
        echo "--> ACTION: Deleting Load Balancer: $arn"
        aws elbv2 delete-load-balancer --load-balancer-arn "$arn" --region "$region"
    elif [[ "$service" == "elasticache" && "$resource_type" == "replicationgroup" ]]; then
        local rg_id=$(echo "$arn" | awk -F: '{print $NF}')
        echo "--> ACTION: Deleting ElastiCache Replication Group: $rg_id"
        aws elasticache delete-replication-group --replication-group-id "$rg_id" --region "$region"
    elif [[ "$service" == "rds" && "$resource_type" == "cluster" ]]; then
        local cluster_id=$(echo "$arn" | awk -F: '{print $NF}')
        echo "--> ACTION: Disabling deletion protection on RDS Cluster: $cluster_id"
        aws rds modify-db-cluster --db-cluster-identifier "$cluster_id" --no-deletion-protection --region "$region" &>/dev/null
        echo "--> ACTION: Deleting RDS Cluster: $cluster_id"
        aws rds delete-db-cluster --db-cluster-identifier "$cluster_id" --skip-final-snapshot --region "$region"
    fi

    # --- Network Gateways & EIPs ---
    if [[ "$service" == "ec2" && "$resource_type" == "natgateway" ]]; then
        echo "--> ACTION: Deleting NAT Gateway: $resource_id"
        aws ec2 delete-nat-gateway --nat-gateway-id "$resource_id" --region "$region"
    elif [[ "$service" == "ec2" && "$resource_type" == "internet-gateway" ]]; then
        vpc_id=$(aws ec2 describe-internet-gateways --internet-gateway-ids "$resource_id" --region "$region" --query "InternetGateways[0].Attachments[0].VpcId" --output text 2>/dev/null)
        if [[ "$vpc_id" != "None" && -n "$vpc_id" ]]; then
            echo "--> ACTION: Detaching Internet Gateway $resource_id from VPC $vpc_id"
            aws ec2 detach-internet-gateway --internet-gateway-id "$resource_id" --vpc-id "$vpc_id" --region "$region"
        fi
        echo "--> ACTION: Deleting Internet Gateway: $resource_id"
        aws ec2 delete-internet-gateway --internet-gateway-id "$resource_id" --region "$region"
    elif [[ "$service" == "ec2" && "$resource_type" == "elastic-ip" ]]; then
        local allocation_id=$(echo "$arn" | awk -F/ '{print $NF}')
        echo "--> ACTION: Releasing Elastic IP with Allocation ID: $allocation_id"
        aws ec2 release-address --allocation-id "$allocation_id" --region "$region"
    fi

    # --- Final Infrastructure (VPC and dependencies) ---
    if [[ "$service" == "ec2" && "$resource_type" == "security-group" ]]; then
        echo "--> ACTION: Deleting Security Group: $resource_id"
        aws ec2 delete-security-group --group-id "$resource_id" --region "$region"
    elif [[ "$service" == "ec2" && "$resource_type" == "subnet" ]]; then
        echo "--> ACTION: Deleting Subnet: $resource_id"
        aws ec2 delete-subnet --subnet-id "$resource_id" --region "$region"
    elif [[ "$service" == "ec2" && "$resource_type" == "route-table" ]]; then
        echo "--> ACTION: Deleting Route Table: $resource_id"
        aws ec2 delete-route-table --route-table-id "$resource_id" --region "$region"
    elif [[ "$service" == "ec2" && "$resource_type" == "vpc" ]]; then
        echo "--> ACTION: Deleting VPC: $resource_id"
        aws ec2 delete-vpc --vpc-id "$resource_id" --region "$region"
    fi
}

# --- Main Script ---
echo "This script will find and DELETE all resources tagged with '$PROJECT_TAG_KEY=$PROJECT_TAG_VALUE'."
read -p "This action is irreversible. Are you sure you want to proceed? (yes/no): " CONFIRM
[[ "$CONFIRM" == "yes" ]] || { echo "Deletion cancelled."; exit 0; }

# Define the order of operations
# Run this script multiple times. The first pass deletes services, the next deletes the VPC components.
for region in "${REGIONS[@]}"; do
    echo -e "\n--- Processing Region: $region ---"
    
    # Get all tagged resources in the region
    resources=$(aws resourcegroupstaggingapi get-resources --region "$region" --tag-filters "Key=$PROJECT_TAG_KEY,Values=$PROJECT_TAG_VALUE" --query 'ResourceTagMappingList[].ResourceARN' --output text)
    
    if [ -z "$resources" ]; then
        echo "No tagged resources found in $region."
        continue
    fi

    for arn in $resources; do
        delete_resources "$arn" "$region"
    done
done

echo -e "\n--- Script finished ---"
echo "NOTE: It may take several minutes for resources to terminate. Run this script again after 5-10 minutes to clean up remaining resources like VPCs."
