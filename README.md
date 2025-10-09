# xelta.ai Infrastructure - Terraform

Enterprise-grade multi-region infrastructure for xelta.ai application platform.

## Architecture Overview

- **Multi-Region Deployment**: `us-east-1`, `eu-central-1` (Frankfurt), `ap-south-1` (Mumbai)
- **Per-Region Resources**: EKS cluster, ElastiCache Redis, Aurora PostgreSQL, VPC with private/public subnets
- **Global Routing**: Route53 latency-based routing directs users to nearest region
- **Security**: AWS Secrets Manager + KMS encryption, IRSA for pod-level IAM, private subnets, encrypted storage
- **Environments**: `dev` (active), `uat`, `prod` (code ready but inactive)

## Prerequisites

- AWS Account with administrative permissions
- AWS CLI configured with credentials (`aws configure`)
- Terraform v1.5+ installed
- Route53 Hosted Zone for `xelta.ai` (already registered)
- `kubectl` installed for EKS management
- **Backend Resources (create these first):**
  - S3 bucket: `xeltainfrastatefiles` (with versioning enabled)
  - DynamoDB table: `xelta-terraform-locks` (with `LockID` as partition key)

### Backend Setup (One-Time)

Create the S3 backend and DynamoDB table:

```sh
# Create S3 bucket for state
aws s3api create-bucket --bucket xeltainfrastatefiles --region us-east-1
aws s3api put-bucket-versioning --bucket xeltainfrastatefiles --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket xeltainfrastatefiles --server-side-encryption-configuration '{ "Rules": [{ "ApplyServerSideEncryptionByDefault": { "SSEAlgorithm": "AES256" } }] }'

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name xelta-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

## Quick Start - Deploy DEV Environment

1.  **Clone repository**
2.  `cd terraform`
3.  **Run bootstrap script for dev environment**
    ```sh
    chmod +x scripts/bootstrap.sh
    ./scripts/bootstrap.sh dev
    ```

The script will:
1.  Initialize Terraform with the remote backend.
2.  Create the `dev` workspace.
3.  Run `terraform plan`.
4.  Prompt for `terraform apply`.

## Manual Deployment Steps

### 1. Initialize Terraform
```sh
cd terraform
terraform init
```

### 2. Select Environment Workspace
```sh
# Create and select dev workspace
terraform workspace new dev
terraform workspace select dev
```

### 3. Plan Infrastructure
```sh
terraform plan -var-file=environments/dev/variables.tfvars
```

### 4. Apply Infrastructure
```sh
terraform apply -var-file=environments/dev/variables.tfvars
```
Deployment takes **25-35 minutes** for EKS clusters, Aurora, and networking resources.

### 5. Configure kubectl Access

After `apply` completes, configure `kubectl` for each region:
```sh
# US East 1
aws eks update-kubeconfig --region us-east-1 --name xelta-dev-eks-us-east-1 --alias xelta-dev-us-east-1

# EU Central 1
aws eks update-kubeconfig --region eu-central-1 --name xelta-dev-eks-eu-central-1 --alias xelta-dev-eu-central-1

# AP South 1
aws eks update-kubeconfig --region ap-south-1 --name xelta-dev-eks-ap-south-1 --alias xelta-dev-ap-south-1
```

## Deploying UAT/PROD Environments

UAT and PROD configurations are included but inactive. To deploy:
1.  Create workspace: `terraform workspace new uat`
2.  Plan with UAT variables: `terraform plan -var-file=environments/uat/variables.tfvars`
3.  Apply: `terraform apply -var-file=environments/uat/variables.tfvars`

> **Important**: Update `environments/uat/variables.tfvars` with production-grade instance sizes before deploying.

## Outputs

After a successful `apply`, Terraform outputs:
- **ALB DNS Names**: Application Load Balancer endpoints per region.
- **EKS Cluster Names**: Cluster identifiers for `kubectl` configuration.
- **Redis Endpoints**: ElastiCache connection strings.
- **Aurora Endpoints**: Database writer/reader endpoints.
- **Secret ARNs**: AWS Secrets Manager secret identifiers.

Example output:
```
alb_dns_us_east_1 = "xelta-dev-alb-us-east-1-123456789.us-east-1.elb.amazonaws.com"
eks_cluster_us_east_1 = "xelta-dev-eks-us-east-1"
redis_endpoint_us_east_1 = "xelta-dev-redis-us-east-1.abcdef.0001.use1.cache.amazonaws.com:6379"
aurora_endpoint_us_east_1 = "xelta-dev-aurora-us-east-1.cluster-abcdefg.us-east-1.rds.amazonaws.com"
db_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:xelta-dev-db-credentials-AbCdEf"
```

## Secrets Management

### Accessing Secrets from EKS Pods
Secrets are stored in AWS Secrets Manager. EKS pods access secrets via IRSA:
1.  Service Account with IAM role annotation (created by Terraform).
2.  Pod specification uses the service account.
3.  AWS Secrets and Configuration Provider (ASCP) mounts secrets as volumes.

Example pod using secrets:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: xelta-app
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/xelta-dev-app-irsa-role
---
apiVersion: v1
kind: Pod
metadata:
  name: xelta-app
spec:
  serviceAccountName: xelta-app
  containers:
  - name: app
    image: xelta/app:latest
    env:
    - name: DB_HOST
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: host
```

### Rotating Secrets
To rotate database credentials:
1.  Generate new password: `NEW_PASSWORD=$(openssl rand -base64 32)`
2.  Update secret in Secrets Manager: `aws secretsmanager update-secret --secret-id xelta-dev-db-credentials --secret-string "{\"username\":\"xeltaadmin\",\"password\":\"$NEW_PASSWORD\"}"`
3.  Update Aurora master password: `aws rds modify-db-cluster --db-cluster-identifier xelta-dev-aurora-us-east-1 --master-user-password "$NEW_PASSWORD" --apply-immediately`

## Route53 Routing Strategy

Traffic routing uses **latency-based routing**:
- Route53 measures latency from the user's location to each AWS region.
- DNS queries return the ALB in the region with the lowest latency.
- Automatic failover if health checks fail.

Example: User in London → routed to `eu-central-1`; User in Tokyo → routed to `ap-south-1`.

### Adding Subdomains for UAT/PROD
To add environment-specific subdomains:
1.  Create Route53 records in `modules/route53_acm/main.tf`:
    ```terraform
    resource "aws_route53_record" "uat_subdomain" {
      count = var.environment == "uat" ? 1 : 0
      zone_id = data.aws_route53_zone.main.zone_id
      name    = "uat.xelta.ai"
      type    = "A"

      alias {
        name                   = var.alb_dns_name
        zone_id                = var.alb_zone_id
        evaluate_target_health = true
      }

      set_identifier = var.region
      latency_routing_policy {
        region = var.region
      }
    }
    ```
2.  Update certificate to include subdomain SANs.

## Security Notes

### Network Isolation
- **Private Subnets**: EKS nodes, Aurora, ElastiCache run in private subnets.
- **NAT Gateways**: One per AZ for outbound internet access from private subnets.
- **Security Groups**: Least-privilege rules (EKS nodes can only access ALB, Aurora, Redis).

### IAM Least Privilege
- **IRSA**: Pods assume IAM roles without embedding credentials.
- **Separate Roles**: Each application component has a dedicated IAM role.
- **Policy Boundaries**: Limit maximum permissions per role.

### Encryption
- **EKS Secrets**: Encrypted using EKS-managed encryption key.
- **Aurora**: Encryption at rest using KMS CMK.
- **ElastiCache**: In-transit (TLS) and at-rest encryption.
- **S3 State**: AES256 encryption for Terraform state.

## Cost Optimization

### Dev Environment Sizing
- **EKS Node Groups**: `t3.medium` instances, 2 nodes per region.
- **Aurora**: `db.t3.medium`, 1 writer + 1 reader per region.
- **ElastiCache**: `cache.t3.micro`, 1 node per region.
- **Estimated Monthly Cost (Dev)**: ~$650-800/month across 3 regions.

### Production Sizing Recommendations
- **EKS**: `m5.xlarge` instances, 4-8 nodes per region with autoscaling.
- **Aurora**: `r6g.xlarge`, 1 writer + 2-3 readers per region.
- **ElastiCache**: `r6g.large`, 2-3 node cluster mode enabled.

## Troubleshooting

### EKS Cluster Unreachable
1.  Verify AWS credentials: `aws sts get-caller-identity`
2.  Update kubeconfig: `aws eks update-kubeconfig --region us-east-1 --name xelta-dev-eks-us-east-1`
3.  Check cluster status: `aws eks describe-cluster --region us-east-1 --name xelta-dev-eks-us-east-1`

### Aurora Connection Issues
1.  Verify security group allows EKS nodes: `aws ec2 describe-security-groups --group-ids sg-xxxxx`
2.  Test connectivity from EKS pod: `kubectl run -it --rm debug --image=busybox --restart=Never -- nc -zv xelta-dev-aurora-us-east-1.cluster-xxxxx.us-east-1.rds.amazonaws.com 5432`

### Terraform State Locked
- Force unlock (use with caution): `terraform force-unlock LOCK_ID`

## Maintenance

### Updating Terraform Modules
1.  Update provider versions: `terraform init -upgrade`
2.  Review changes: `terraform plan -var-file=environments/dev/variables.tfvars`

### EKS Version Upgrades
1.  Update `eks_version` in `environments/dev/variables.tfvars`.
2.  Run `terraform plan` to preview changes.
3.  Apply during a maintenance window.
4.  Update node groups (Terraform will perform a rolling update).

## Module Documentation

- `vpc`: Creates VPC with public/private subnets across 3 AZs, NAT gateways, IGW.
- `eks`: Provisions EKS cluster, OIDC provider, managed node groups, IRSA roles.
- `alb_ingress`: Creates ALB, target groups, security groups for ingress traffic.
- `route53_acm`: Manages Route53 records, ACM certificates with DNS validation.
- `rds_aurora`: Deploys Aurora PostgreSQL cluster with encryption and backups.
- `elasticache_redis`: Creates Redis replication group with encryption.
- `kms`: Generates KMS customer-managed keys for encryption.
- `secrets`: Stores credentials and sensitive configuration in Secrets Manager.
- `iam`: Creates IAM roles, policies for EKS IRSA and service access.

## Support

For infrastructure issues or questions:
- Review Terraform outputs: `terraform output`
- Check CloudWatch Logs for EKS control plane logs.
- Review AWS Security Hub findings.

---
*Internal use only - xelta.ai infrastructure.*