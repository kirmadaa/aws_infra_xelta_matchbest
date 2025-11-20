#!/bin/bash
set -e

# Script to install AWS Load Balancer Controller on EKS cluster
# Usage: ./install-lb-controller.sh [dev|uat|prod] [us-east-1|eu-central-1|ap-south-1]

ENVIRONMENT=${1:-dev}
REGION=${2:-us-east-1}
CLUSTER_NAME="xelta-$ENVIRONMENT-eks-$REGION"

echo "Installing AWS Load Balancer Controller on $CLUSTER_NAME..."

# Update kubeconfig
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

# Install cert-manager
kubectl apply --validate=false -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager
echo "Waiting for cert-manager to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager

# Get cluster VPC ID
VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query "cluster.resourcesVpcConfig.vpcId" --output text)

# Install AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=true \
  --set region="$REGION" \
  --set vpcId="$VPC_ID"

echo "✓ AWS Load Balancer Controller installed"