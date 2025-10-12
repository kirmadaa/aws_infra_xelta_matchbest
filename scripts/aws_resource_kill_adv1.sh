#!/bin/bash

# WARNING: This script permanently deletes AWS resources and is irreversible.
# It is designed to be run multiple times to handle the full dependency chain.

# --- Configuration ---
PROJECT_TAG_KEY="Project"
PROJECT_TAG_VALUE="xelta"
REGIONS=("us-east-1" "eu-central-1" "ap-south-1")

# --- Main Script ---
echo "This script will find and DELETE all resources tagged with '$PROJECT_TAG_KEY=$PROJECT_TAG_VALUE'."
read -p "This action is irreversible. Are you sure you want to proceed? (yes/no): " CONFIRM
[[ "$CONFIRM" == "yes" ]] || { echo "Deletion cancelled."; exit 0; }

# --- PASS 1: Delete High-Level Application Services ---
echo -e "\n--- PASS 1: Deleting EKS Node Groups, Load Balancers, RDS & ElastiCache Clusters ---"
for region in "${REGIONS[@]}"; do
    echo -e "\n--- Processing Region: $region ---"
    resources=$(aws resourcegroupstaggingapi get-resources --region "$region" --tag-filters "Key=$PROJECT_TAG_KEY,Values=$PROJECT_TAG_VALUE" --query 'ResourceTagMappingList[].ResourceARN' --output text)
    if [ -z "$resources" ]; then continue; fi

    # Delete EKS Node Groups FIRST
    for arn in $(echo "$resources" | grep ":eks:.*:nodegroup/"); do
        cluster_name=$(echo "$arn" | awk -F/ '{print $(NF-2)}')
        nodegroup_name=$(echo "$arn" | awk -F/ '{print $NF}')
        echo "--> Deleting EKS Node Group: $nodegroup_name in cluster $cluster_name"
        aws eks delete-nodegroup --cluster-name "$cluster_name" --nodegroup-name "$nodegroup_name" --region "$region"
    done

    # Delete Load Balancers
    for arn in $(echo "$resources" | grep ":elasticloadbalancing:.*:loadbalancer/app/"); do
        echo "--> Deleting Load Balancer: $arn"
        aws elbv2 delete-load-balancer --load-balancer-arn "$arn" --region "$region"
    done
    
    # Delete RDS Clusters
    for arn in $(echo "$resources" | grep ":rds:.*:cluster:"); do
        cluster_id=$(echo "$arn" | awk -F: '{print $NF}')
        echo "--> Disabling deletion protection on RDS Cluster: $cluster_id"
        aws rds modify-db-cluster --db-cluster-identifier "$cluster_id" --no-deletion-protection --region "$region" &>/dev/null
        echo "--> Deleting RDS Cluster: $cluster_id"
        aws rds delete-db-cluster --db-cluster-identifier "$cluster_id" --skip-final-snapshot --region "$region"
    done

    # Delete ElastiCache Replication Groups
    for arn in $(echo "$resources" | grep ":elasticache:.*:replicationgroup:"); do
        rg_id=$(echo "$arn" | awk -F: '{print $NF}')
        echo "--> Deleting ElastiCache Replication Group: $rg_id"
        aws elasticache delete-replication-group --replication-group-id "$rg_id" --region "$region"
    done
done

echo -e "\n--- PASS 1 COMPLETE ---"
echo "Waiting for 5 minutes for services and node groups to terminate..."
sleep 300

# --- PASS 2: Delete EKS Clusters and Network Infrastructure ---
echo -e "\n--- PASS 2: Deleting EKS Clusters, Network Gateways, and EIPs ---"
for region in "${REGIONS[@]}"; do
    echo -e "\n--- Processing Region: $region ---"
    resources=$(aws resourcegroupstaggingapi get-resources --region "$region" --tag-filters "Key=$PROJECT_TAG_KEY,Values=$PROJECT_TAG_VALUE" --query 'ResourceTagMappingList[].ResourceARN' --output text)
    if [ -z "$resources" ]; then continue; fi
    
    # Delete EKS Clusters (now that nodegroups are gone)
    for arn in $(echo "$resources" | grep ":eks:.*:cluster"); do
        cluster_name=$(echo "$arn" | awk -F/ '{print $NF}')
        echo "--> Deleting EKS Cluster: $cluster_name"
        aws eks delete-cluster --name "$cluster_name" --region "$region"
    done

    # Detach and Delete Internet Gateways
    for arn in $(echo "$resources" | grep ":ec2:.*:internet-gateway/"); do
        igw_id=$(echo "$arn" | awk -F/ '{print $NF}')
        vpc_id=$(aws ec2 describe-internet-gateways --internet-gateway-ids "$igw_id" --region "$region" --query "InternetGateways[0].Attachments[0].VpcId" --output text 2>/dev/null)
        if [[ "$vpc_id" != "None" && -n "$vpc_id" ]]; then
            echo "--> Detaching Internet Gateway $igw_id from VPC $vpc_id"
            aws ec2 detach-internet-gateway --internet-gateway-id "$igw_id" --vpc-id "$vpc_id" --region "$region"
        fi
        echo "--> Deleting Internet Gateway: $igw_id"
        aws ec2 delete-internet-gateway --internet-gateway-id "$igw_id" --region "$region"
    done
    
    # Delete NAT Gateways
     for arn in $(echo "$resources" | grep ":ec2:.*:natgateway/"); do
        resource_id=$(echo "$arn" | awk -F/ '{print $NF}')
        echo "--> Deleting NAT Gateway: $resource_id"
        aws ec2 delete-nat-gateway --nat-gateway-id "$resource_id" --region "$region"
    done
    
    # Release Elastic IPs
    for arn in $(echo "$resources" | grep ":ec2:.*:elastic-ip/"); do
        allocation_id=$(echo "$arn" | awk -F/ '{print $NF}')
        echo "--> Releasing Elastic IP (Allocation ID): $allocation_id"
        aws ec2 release-address --allocation-id "$allocation_id" --region "$region"
    done
done

echo -e "\n--- PASS 2 COMPLETE ---"
echo "Waiting for 2 minutes for clusters and gateways to terminate..."
sleep 120

# --- PASS 3: Delete Remaining VPC Components ---
echo -e "\n--- PASS 3: Deleting Security Groups, Subnets, and VPCs ---"
for region in "${REGIONS[@]}"; do
    echo -e "\n--- Processing Region: $region ---"
    resources=$(aws resourcegroupstaggingapi get-resources --region "$region" --tag-filters "Key=$PROJECT_TAG_KEY,Values=$PROJECT_TAG_VALUE" --query 'ResourceTagMappingList[].ResourceARN' --output text)
    if [ -z "$resources" ]; then continue; fi
    
    # Delete Security Groups, Subnets, Route Tables, and finally the VPC
    for resource_type in security-group subnet route-table vpc; do
        for arn in $(echo "$resources" | grep ":ec2:.*:${resource_type}/"); do
            resource_id=$(echo "$arn" | awk -F/ '{print $NF}')
            echo "--> Deleting EC2 ${resource_type}: $resource_id"
            aws ec2 delete-${resource_type} --${resource_type}-id "$resource_id" --region "$region"
        done
    done
done

echo -e "\n--- ALL PASSES COMPLETE ---"
echo "Script finished. Please check the AWS Console to verify resource deletion."
