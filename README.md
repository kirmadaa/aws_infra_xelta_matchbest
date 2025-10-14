# Xelta Infrastructure

This repository contains the Terraform code to provision a secure, scalable, and production-ready infrastructure on AWS for the Xelta project. The infrastructure is designed with a security-first mindset, where all components are private by default and access is strictly controlled.

## Project Philosophy

*   **Zero-Trust Networking:** No component trusts another by default. Access is granted via explicit security group rules.
*   **Private by Default:** All EKS nodes, databases, and cache clusters reside in private subnets with no direct internet access.
*   **ALB as the Secure Gateway:** The Application Load Balancer (ALB) is the primary entry point for traffic, protected by AWS WAF and CloudFront.
*   **Infrastructure as Code:** The entire infrastructure is defined using Terraform, enabling consistent and repeatable deployments.
*   **Asynchronous Job Processing:** A dedicated ECS worker service processes long-running tasks asynchronously using SQS queues and stores outputs in a secure S3 bucket.
*   **Automation-Ready:** The project includes a GitHub Actions workflow for automated CI/CD.

## Prerequisites

Before you begin, ensure you have the following:

1.  **AWS Account:** An active AWS account with the necessary permissions to create the resources defined in this project.
2.  **Registered Domain:** A domain name registered in AWS Route 53. You will need the **Hosted Zone ID** of this parent domain.
3.  **Terraform CLI:** Terraform installed on your local machine.
4.  **AWS CLI:** The AWS CLI installed and configured with credentials for your AWS account.
5.  **Helm:** The Helm CLI installed for deploying Kubernetes packages.

## Project Structure

The project is organized into two main directories:

*   `terraform/modules`: Contains reusable Terraform modules for different parts of the infrastructure (VPC, EKS, Database, Edge, SQS, S3 Outputs).
*   `terraform/environments`: Contains the root configurations for each environment (`dev`, `prod`). Each environment is configured for a specific AWS region.
*   `kubernetes-examples`: Contains example Kubernetes manifests, such as the `secure-ingress.yaml` file.

## Configuration

### 1. Set Up the Terraform Backend

The Terraform state is stored remotely in an S3 bucket for security and collaboration. You need to create an S3 bucket and a DynamoDB table (for state locking) in your AWS account.

Once created, update the `backend "s3"` block in `terraform/environments/<env>/region_*/main.tf` for both the `dev` and `prod` environments with your bucket name, desired key, and DynamoDB table name.

```terraform
# terraform/environments/dev/region_eu-west-3/main.tf

terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "xelta-dev-eu-west-3.tfstate"
    region         = "eu-west-3"
    dynamodb_table = "your-terraform-lock-table"
  }
  # ...
}
```

### 2. Configure Environment Variables

For each environment you want to deploy (`dev`, `prod`), navigate to its directory (e.g., `terraform/environments/dev/region_eu-west-3/`) and create a `terraform.tfvars` file by copying the example:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Now, edit `terraform.tfvars` and fill in the required values:

*   `domain_name`: The full domain name for the environment (e.g., `dev.xelta.com`).
*   `parent_zone_id`: The **Hosted Zone ID** of your root domain in Route 53 (e.g., the zone ID for `xelta.com`).
*   `backend_image`, `frontend_image`, `worker_image`: The Docker image URIs for the respective services.

All other variables are pre-configured with sensible defaults for their respective environments, but you can adjust them as needed.

## Manual Deployment

To deploy the infrastructure manually, follow these steps:

1.  **Navigate to the Environment Directory:**
    ```bash
    cd terraform/environments/dev/region_eu-west-3
    ```

2.  **Initialize Terraform:**
    This will download the necessary provider plugins and configure the backend.
    ```bash
    terraform init
    ```

3.  **Plan the Deployment:**
    Review the changes that Terraform will make.
    ```bash
    terraform plan -var-file=terraform.tfvars
    ```

4.  **Apply the Changes:**
    Provision the infrastructure.
    ```bash
    terraform apply -var-file=terraform.tfvars --auto-approve
    ```

## Post-Deployment Steps

After the infrastructure is deployed, you need to configure `kubectl` and install the AWS Load Balancer Controller on the EKS cluster.

1.  **Configure `kubectl`:**
    Run the following command, replacing `<your-region>` and `<your-env>` with your environment's details (e.g., `eu-west-3`, `dev`).
    ```bash
    aws eks update-kubeconfig --region <your-region> --name xelta-<your-env>
    ```

2.  **Install AWS Load Balancer Controller:**
    The IAM role for the controller has already been created by Terraform. Now, install the controller using Helm.
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
    You can now deploy your application to the EKS cluster. Use the `kubernetes-examples/secure-ingress.yaml` file as a template for exposing your services through the ALB.

    You will need to replace the placeholders in the Ingress manifest with the outputs from Terraform:
    *   `alb.ingress.kubernetes.io/wafv2-acl-arn`: Get this value by running `terraform output waf_arn`.
    *   `alb.ingress.kubernetes.io/security-groups`: Get this value by running `terraform output alb_security_group_id`.

## GitHub Actions Deployment

This repository includes a GitHub Actions workflow in `.github/workflows/deploy.yml` for automated deployments.

### Prerequisites for GitHub Actions

1.  **AWS OIDC Provider:** You must have an IAM OIDC provider configured in your AWS account to allow GitHub Actions to securely authenticate.
2.  **IAM Roles:** Create IAM roles that the GitHub Actions workflow can assume. These roles need permissions to deploy the Terraform resources.
3.  **Repository Secrets:** Configure the following secrets in your GitHub repository settings:
    *   `AWS_ROLE_DEV`: The ARN of the IAM role for deploying the `dev` environment.
    *   `AWS_ROLE_PROD`: The ARN of the IAM role for deploying the `prod` environment.

### Workflow Triggers

*   **Dev Environment:** The `dev` environment is deployed automatically on every push to the `main` branch.
*   **Prod Environment:** The `prod` environment deployment is a manual workflow that must be triggered from the GitHub Actions UI. This provides a safety gate for production deployments.
