# Xelta Infrastructure

This repository contains the Terraform code to provision a secure, scalable, and production-ready infrastructure on AWS for the Xelta project. The infrastructure is designed with a Product-Based Architecture.

## Project Philosophy

*   **Product-Based Architecture:** Each product (e.g., Xelta) is a self-contained application module. A boolean flag can enable or disable the entire product stack.
*   **Zero-Trust Networking:** No component trusts another by default. Access is granted via explicit security group rules.
*   **Private by Default:** All ECS tasks, databases, and cache clusters reside in private subnets with no direct internet access.
*   **Infrastructure as Code:** The entire infrastructure is defined using Terraform, enabling consistent and repeatable deployments.

## Prerequisites

Before you begin, ensure you have the following:

1.  **AWS Account:** An active AWS account with the necessary permissions to create the resources defined in this project.
2.  **Registered Domain:** A domain name registered in AWS Route 53.
3.  **Terraform CLI:** Terraform installed on your local machine.
4.  **AWS CLI:** The AWS CLI installed and configured with credentials for your AWS account.

## Project Structure

The project is organized into the following directories:

*   `modules/microservice`: A generic, reusable Terraform module for deploying a single microservice to ECS.
*   `apps/xelta`: An application module that defines all the services for the Xelta product (e.g., frontend, backend).
*   `environments/dev`: Contains the root configuration for the `dev` environment.

## Configuration

### 1. Set Up the Terraform Backend

The Terraform state is stored remotely in an S3 bucket. You need to create an S3 bucket and a DynamoDB table (for state locking) in your AWS account.

Once created, update the `backend "s3"` block in `environments/dev/main.tf` with your bucket name, desired key, and DynamoDB table name.

```terraform
# environments/dev/main.tf

terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "xelta-dev.tfstate"
    region         = "us-east-1"
    dynamodb_table = "your-terraform-lock-table"
  }
}
```

### 2. Configure Environment Variables

For the environment you want to deploy, navigate to its directory (e.g., `environments/dev/`) and edit the `variables.tfvars` file.

The most important variable is the "kill switch":

*   `enable_xelta`: Set to `true` to deploy the Xelta stack, or `false` to destroy it.

## How to Use the Kill Switch

In your `environments/dev/variables.tfvars` file:

To deploy the Xelta application:
```
enable_xelta = true
```

To destroy the entire Xelta application stack:
```
enable_xelta = false
```
When you apply this change, Terraform will see that the `count` for the `apps/xelta` module is 0 and will destroy all associated resources.

## Manual Deployment

To deploy the infrastructure manually, follow these steps:

1.  **Navigate to the Environment Directory:**
    ```bash
    cd environments/dev
    ```

2.  **Initialize Terraform:**
    This will download the necessary provider plugins and configure the backend.
    ```bash
    terraform init
    ```

3.  **Plan the Deployment:**
    Review the changes that Terraform will make.
    ```bash
    terraform plan
    ```

4.  **Apply the Changes:**
    Provision the infrastructure.
    ```bash
    terraform apply --auto-approve
    ```
