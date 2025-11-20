# Terraform Infrastructure Walkthrough

This document explains the new directory structure and how to manage the infrastructure.

## Directory Structure

```
.
├── modules/
│   ├── application_regional_stack/  # Generic app stack (ECS Cluster, Service, Lambdas, etc.)
│   ├── shared_regional_stack/       # Shared infra (VPC, ALB, NLB)
│   ├── cdn/                         # Generic CDN module
│   └── ... (other modules)
├── teams/
│   ├── xelta/                       # Infrastructure for 'xelta' team
│   │   ├── main.tf                  # Orchestrates shared + app stacks
│   │   ├── variables.tf
│   │   └── ...
│   └── [new-team]/                  # Future teams
```

## Key Concepts

### 1. Shared vs. Application Infrastructure
-   **Shared Infrastructure**: VPCs, ALBs, and NLBs are created ONCE per region. These are the expensive/foundational resources.
-   **Application Infrastructure**: ECS Clusters, Services, IAM Roles, Target Groups, and Lambdas are created PER TEAM. This ensures full isolation of compute resources.

### 2. The "Destroy Switch"
-   Set `enable_infrastructure = false` in your `tfvars` file to destroy all resources for a specific environment/team.
-   This uses the `count` meta-argument on modules.

### 3. Multi-Team Support
To onboard a new team (e.g., "Team Y"):

1.  **Create Directory**: Copy `teams/xelta` to `teams/team-y`.
2.  **Update `main.tf`**:
    *   **REMOVE** the `module "shared_regional_stack"` blocks. Team Y should NOT deploy shared infra.
    *   **UPDATE** the `module "us_east_1_stack"` (and others) to reference the *existing* shared infrastructure IDs (VPC ID, ALB ARN). You can hardcode them or use `terraform_remote_state`.
    *   **CHANGE** `app_name` to `"team-y"`.
    *   **CHANGE** `app_port` to a unique port (e.g., `8081`) to avoid conflicts on the shared NLB.
    *   **CHANGE** `lb_path_pattern` to something unique (e.g., `/team-y/*`) to avoid routing conflicts.

## Deployment

1.  **Init**: `terraform init -backend-config=environments/dev/dev.tfbackend`
2.  **Plan**: `terraform plan -var-file=environments/dev/variables.tfvars`
3.  **Apply**: `terraform apply -var-file=environments/dev/variables.tfvars`

## Shared Infrastructure Details

The `shared_regional_stack` creates:
-   **VPC**: With public/private subnets.
-   **ALB**: `shared-fe-<env>-<region>` (Public)
-   **NLB**: `shared-<env>-<region>-nlb` (Internal)

**Note**: The ECS Cluster is NO LONGER shared. Each application stack creates its own cluster (e.g., `xelta-dev-us-east-1`, `team-y-dev-us-east-1`).
