# Xelta Infrastructure

This repository contains the Terraform code to provision a secure, scalable, and production-ready infrastructure on AWS for the Xelta project. The infrastructure is defined from a single set of Terraform files and uses **Terraform Workspaces** to manage multiple environments (`dev`, `prod`, etc.).

## Project Philosophy

*   **DRY (Don't Repeat Yourself):** A single, unified Terraform configuration is used for all environments, with environment-specific settings managed through `.tfvars` files.
*   **Zero-Trust Networking:** No component trusts another by default. Access is granted via explicit security group rules.
*   **Private by Default:** All EKS nodes, databases, and cache clusters reside in private subnets with no direct internet access.
*   **ALB as the Secure Gateway:** The Application Load Balancer (ALB) is the primary entry point for traffic, protected by AWS WAF and CloudFront.
*   **Automation-Ready:** The project includes a GitHub Actions workflow for automated, workspace-aware CI/CD.

## Prerequisites

Before you begin, ensure you have the following:

1.  **AWS Account:** An active AWS account with the necessary permissions to create the resources defined in this project.
2.  **Registered Domain:** A domain name registered in AWS Route 53. You will need the **Hosted Zone ID** of this parent domain.
3.  **Terraform CLI (v1.0+):** Terraform installed on your local machine.
4.  **AWS CLI:** The AWS CLI installed and configured with credentials for your AWS account.
5.  **Helm:** The Helm CLI installed for deploying Kubernetes packages.

## Project Structure

*   `terraform/modules`: Contains reusable Terraform modules for different parts of the infrastructure (VPC, EKS, Database, Edge).
*   `terraform/live`: The root directory for the live infrastructure configuration. All `terraform` commands are run from here.
*   `terraform/live/env_vars`: Contains the environment-specific variable files (`dev.tfvars`, `prod.tfvars`).
*   `kubernetes-examples`: Contains example Kubernetes manifests.

## Configuration

### 1. Set Up the Terraform Backend

The Terraform state is stored remotely in an S3 bucket. You need to create an S3 bucket and a DynamoDB table (for state locking) in your AWS account.

Once created, update the `backend "s3"` block in `terraform/live/main.tf` with your bucket name, a base key, and your DynamoDB table name. Terraform will automatically manage state files for each workspace under the specified key.

```terraform
# terraform/live/main.tf

terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "xelta/terraform.tfstate" # Base key for all workspaces
    region         = "eu-west-3"
    dynamodb_table = "your-terraform-lock-table"
  }
  # ...
}
```

### 2. Configure Environment Variables

The environment-specific variables are defined in `terraform/live/env_vars/`. You need to edit `dev.tfvars` and `prod.tfvars` and provide a value for `parent_zone_id`.

*   `parent_zone_id`: The **Hosted Zone ID** of your root domain in Route 53 (e.g., the zone ID for `xelta.com`).

You can also adjust any other variables in these files as needed for each environment.

## Manual Deployment with Workspaces

All commands should be run from the `terraform/live` directory.

1.  **Navigate to the Live Directory:**
    ```bash
    cd terraform/live
    ```

2.  **Initialize Terraform:**
    This will download the necessary provider plugins and configure the backend.
    ```bash
    terraform init
    ```

3.  **Create and Select a Workspace:**
    Terraform uses workspaces to manage different environments. Create a workspace for `dev` and/or `prod`.
    ```bash
    # Create the dev workspace (only needs to be done once)
    terraform workspace new dev

    # Select the dev workspace
    terraform workspace select dev
    ```

4.  **Plan the Deployment:**
    Review the changes that Terraform will make for the selected workspace. You must specify the corresponding `.tfvars` file.
    ```bash
    # For the dev workspace
    terraform plan -var-file="env_vars/dev.tfvars"
    ```

5.  **Apply the Changes:**
    Provision the infrastructure for the selected workspace.
    ```bash
    # For the dev workspace
    terraform apply -var-file="env_vars/dev.tfvars" --auto-approve
    ```

To deploy the `prod` environment, simply select the `prod` workspace and use `prod.tfvars`:
```bash
terraform workspace new prod
terraform workspace select prod
terraform plan -var-file="env_vars/prod.tfvars"
terraform apply -var-file="env_vars/prod.tfvars" --auto-approve
```

## Post-Deployment Steps

After the infrastructure is deployed, you need to configure `kubectl` and install the AWS Load Balancer Controller.

1.  **Configure `kubectl`:**
    Run the following command, replacing `<your-region>` and `<your-env>` with your environment's details (e.g., `eu-west-3`, `dev`).
    ```bash
    aws eks update-kubeconfig --region <your-region> --name xelta-<your-env>
    ```

2.  **Install AWS Load Balancer Controller:**
    ```bash
    helm repo add eks https://aws.github.io/eks-charts
    helm repo update
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
      -n kube-system \
      --set clusterName=xelta-<your-env> \
      --set serviceAccount.create=false \
      --set serviceAccount.name=aws-load-balancer-controller
    ```

3.  **Deploy Your Application:**
    Use the `kubernetes-examples/secure-ingress.yaml` manifest as a template. You will need to replace the placeholders with the outputs from Terraform for the currently selected workspace:
    *   `alb.ingress.kubernetes.io/wafv2-acl-arn`: Get this value by running `terraform output waf_arn`.
    *   `alb.ingress.kubernetes.io/security-groups`: Get this value by running `terraform output alb_security_group_id`.

## GitHub Actions Deployment

The GitHub Actions workflow in `.github/workflows/deploy.yml` uses Terraform workspaces to deploy automatically.

### Prerequisites for GitHub Actions

1.  **AWS OIDC Provider:** You must have an IAM OIDC provider configured in your AWS account.
2.  **IAM Roles:** Create IAM roles that the GitHub Actions workflow can assume.
3.  **Repository Secrets:** Configure the following secrets in your GitHub repository settings:
    *   `AWS_ROLE_DEV`: The ARN of the IAM role for deploying the `dev` environment.
    *   `AWS_ROLE_PROD`: The ARN of the IAM role for deploying the `prod` environment.

### Workflow Triggers

*   **Dev Environment:** The `dev` environment is deployed automatically on every push to the `main` branch.
*   **Prod Environment:** The `prod` environment deployment is a manual workflow that must be triggered from the GitHub Actions UI. This provides a safety gate for production deployments.