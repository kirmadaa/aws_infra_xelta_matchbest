# Operational Runbook

This runbook provides step-by-step procedures for common operational tasks.

## Table of Contents
- [Deploying to New Regions](#deploying-to-new-regions)
- [Onboarding New Teams](#onboarding-new-teams)
- [Rolling Back Deployments](#rolling-back-deployments)
- [Disaster Recovery](#disaster-recovery)
- [Troubleshooting](#troubleshooting)

---

## Deploying to New Regions

### Prerequisites
- AWS account with necessary permissions
- S3 bucket for Terraform state (or use existing)
- Route53 hosted zone for your domain

### Steps

1. **Update Regional Configuration**
   ```bash
   cd teams/xelta
   ```
   
   Edit `variables.tf` to add the new region:
   ```hcl
   variable "regions" {
     default = ["us-east-1", "eu-central-1", "ap-south-1", "ap-southeast-1"]  # Add new region
   }
   ```

2. **Add VPC CIDR Block**
   In `teams/xelta/environments/dev/variables.tfvars`:
   ```hcl
   vpc_cidr_blocks = {
     # ... existing regions ...
     "ap-southeast-1" = "10.4.0.0/16"  # New region
   }
   ```

3. **Add Image References**
   ```hcl
   frontend_images = {
     # ... existing ...
     "ap-southeast-1" = "123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/frontend:latest"
   }
   ```

4. **Update main.tf**
   Add a new module block for the region:
   ```hcl
   module "shared_ap_southeast_1" {
     source = "../../modules/shared_regional_stack"
     providers = { aws = aws.ap_southeast_1 }
     # ... configuration ...
   }
   
   module "ap_southeast_1_stack" {
     source = "../../modules/application_regional_stack"
     count  = var.enable_infrastructure ? 1 : 0
     # ... configuration ...
   }
   ```

5. **Update CDN Origins**
   In `teams/xelta/main.tf`, add the new ALB to CDN origins:
   ```hcl
   origins = {
     # ... existing ...
     ap-southeast-1 = try(module.shared_ap_southeast_1.frontend_alb_dns_name, "")
   }
   ```

6. **Apply Changes**
   ```bash
   terraform init -backend-config=environments/dev/dev.tfbackend
   terraform plan -var-file=environments/dev/variables.tfvars
   terraform apply -var-file=environments/dev/variables.tfvars
   ```

---

## Onboarding New Teams

### Overview
New teams share VPC and ALB but get their own ECS Clusters and resources.

### Steps

1. **Create Team Directory**
   ```bash
   cp -r teams/xelta teams/team-y
   cd teams/team-y
   ```

2. **Update Variables**
   Edit `variables.tf` and change all occurrences of "xelta" to "team-y"

3. **Remove Shared Infrastructure**
   Edit `main.tf`:
   ```hcl
   # DELETE these blocks:
   # module "shared_us_east_1" { ... }
   # module "shared_eu_central_1" { ... }
   # module "shared_ap_south_1" { ... }
   ```

4. **Reference Existing Shared Infrastructure**
   
   **Option A: Hardcode (Quick)**
   ```hcl
   module "us_east_1_stack" {
     # ...
     vpc_id                    = "vpc-xxxxx"  # From Xelta's output
     private_subnet_ids        = ["subnet-aaa", "subnet-bbb"]
     frontend_alb_listener_arn = "arn:aws:elasticloadbalancing:..."
     # ...
   }
   ```

   **Option B: Remote State (Recommended)**
   ```hcl
   data "terraform_remote_state" "shared_infra" {
     backend = "s3"
     config = {
       bucket = "xeltastate"
       key    = "xelta/dev/terraform.tfstate"
       region = "us-east-1"
     }
   }
   
   module "us_east_1_stack" {
     # ...
     vpc_id = data.terraform_remote_state.shared_infra.outputs.vpc_id_us_east_1
     # ...
   }
   ```

5. **Set Unique Values**
   ```hcl
   app_name        = "team-y"
   app_port        = 8081  # Must be unique!
   lb_path_pattern = "/team-y/*"  # Must be unique!
   lb_priority     = 200  # Must be unique!
   ```

6. **Create Backend Config**
   ```bash
   mkdir -p environments/dev
   echo 'key = "team-y/dev/terraform.tfstate"' > environments/dev/dev.tfbackend
   ```

7. **Deploy**
   ```bash
   terraform init -backend-config=environments/dev/dev.tfbackend
   terraform apply -var-file=environments/dev/variables.tfvars
   ```

---

## Rolling Back Deployments

### Option 1: Terraform State Rollback

1. **List State Versions**
   ```bash
   aws s3 ls s3://xeltastate/xelta/dev/ --recursive
   ```

2. **Download Previous State**
   ```bash
   aws s3 cp s3://xeltastate/xelta/dev/terraform.tfstate.backup ./terraform.tfstate
   ```

3. **Replace Current State**
   ```bash
   terraform state push terraform.tfstate
   ```

4. **Apply Old State**
   ```bash
   terraform apply -var-file=environments/dev/variables.tfvars
   ```

### Option 2: Git Revert + Re-apply

1. **Find Last Good Commit**
   ```bash
   git log --oneline
   ```

2. **Revert Code**
   ```bash
   git revert <bad-commit-sha>
   ```

3. **Re-apply**
   ```bash
   terraform apply -var-file=environments/dev/variables.tfvars
   ```

### Option 3: ECS Task Definition Rollback

For application-only issues (not infrastructure):

1. **List Task Definitions**
   ```bash
   aws ecs list-task-definitions --family-prefix xelta-dev-frontend
   ```

2. **Update Service**
   ```bash
   aws ecs update-service \
     --cluster xelta-dev-us-east-1 \
     --service xelta-dev-frontend \
     --task-definition xelta-dev-frontend:42  # Previous version
   ```

---

## Disaster Recovery

### Regional Failure

**Scenario**: `us-east-1` becomes unavailable

**Response**:
1. **CloudFront Auto-Failover**: Lambda@Edge automatically routes traffic to `eu-central-1`
2. **Verify Health**: Check remaining regions
   ```bash
   curl https://api.yourdomain.com/health
   ```
3. **Monitor**: Watch CloudWatch metrics for spike in EU traffic

**Recovery**:
1. Wait for AWS region recovery
2. ECS services will auto-restart
3. Verify:
   ```bash
   aws ecs describe-services --cluster xelta-dev-us-east-1 --services xelta-dev-frontend
   ```

### Complete Data Loss (S3/DynamoDB Deleted)

**Prevention**:
- Enable S3 versioning
- Enable DynamoDB Point-in-Time Recovery (PITR)

**Recovery**:
```bash
# Restore S3 from version
aws s3api list-object-versions --bucket xelta-dev-results-us-east-1

# Restore DynamoDB
aws dynamodb restore-table-to-point-in-time \
  --source-table-name xelta-dev-jobs-us-east-1 \
  --target-table-name xelta-dev-jobs-us-east-1-restored \
  --restore-date-time 2025-01-20T00:00:00Z
```

### State File Corruption

1. **Enable S3 Versioning** (prevention):
   ```bash
   aws s3api put-bucket-versioning \
     --bucket xeltastate \
     --versioning-configuration Status=Enabled
   ```

2. **Restore Previous Version**:
   ```bash
   aws s3api list-object-versions --bucket xeltastate --prefix xelta/dev/terraform.tfstate
   aws s3api get-object \
     --bucket xeltastate \
     --key xelta/dev/terraform.tfstate \
     --version-id <VERSION_ID> \
     terraform.tfstate
   ```

---

## Troubleshooting

### ECS Task Won't Start

**Symptoms**: Tasks immediately stop with `STOPPED` status

**Diagnosis**:
```bash
aws ecs describe-tasks --cluster xelta-dev-us-east-1 --tasks <task-id>
```

**Common Causes**:
1. **Image Pull Failure**: Check ECR permissions
   ```bash
   aws ecr get-login-password | docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com
   ```

2. **Insufficient CPU/Memory**: Check `stoppedReason` in task description

3. **Health Check Failure**: Verify application responds on `/health`

### High NAT Gateway Costs

**Investigation**:
1. Check VPC Flow Logs for top talkers:
   ```sql
   SELECT srcaddr, dstaddr, SUM(bytes) as total_bytes
   FROM vpc_flow_logs
   WHERE action = 'ACCEPT'
   GROUP BY srcaddr, dstaddr
   ORDER BY total_bytes DESC
   LIMIT 10;
   ```

2. **Verify VPC Endpoints**: Ensure S3/DynamoDB traffic uses gateway endpoints
   ```bash
   aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=vpc-xxxxx"
   ```

### CloudFront Not Routing Correctly

**Check Lambda@Edge Logs**:
```bash
aws logs filter-log-events \
  --log-group-name /aws/lambda/us-east-1.edge_router \
  --start-time $(date -u -d '1 hour ago' +%s)000
```

**Verify Origin Health**:
```bash
aws cloudfront get-distribution --id <DIST_ID> | jq '.Distribution.DistributionConfig.Origins'
```

### Terraform State Lock

**Symptoms**: `Error acquiring the state lock`

**Resolution**:
```bash
# List locks
aws dynamodb scan --table-name xeltastate-lock

# Force unlock (DANGER: only if you're sure no one else is running terraform)
terraform force-unlock <LOCK_ID>
```

---

## Maintenance Windows

### Recommended Schedule
- **Dev**: Rolling updates anytime
- **UAT**: Tuesdays/Thursdays, 10 AM UTC
- **Prod**: Saturdays, 2 AM UTC (lowest traffic)

### Pre-Maintenance Checklist
- [ ] Notify stakeholders
- [ ] Create database snapshots
- [ ] Verify rollback procedure
- [ ] Check AWS Health Dashboard for region issues
- [ ] Increase CloudWatch log retention to 30 days

### Post-Maintenance Verification
- [ ] Smoke test all endpoints
- [ ] Check error rates in CloudWatch
- [ ] Verify no 5xx errors in ALB metrics
- [ ] Confirm ECS desired count matches running count
