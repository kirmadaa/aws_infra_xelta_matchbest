# Xelta Infrastructure

This repository contains the Terraform code to provision a secure, scalable, and multi-region infrastructure on AWS for the Xelta project. The infrastructure is designed with a **Multi-Region Shared Platform** model.

## Project Philosophy

*   **Multi-Region Shared Platform:** Core infrastructure resources, such as the ECS Cluster and Application Load Balancer (ALB), are defined once **per region**. This provides high availability and reduces cost and management complexity within each region.
*   **Product-Based Architecture:** Each product (e.g., Xelta) is a self-contained application module that "plugs into" the shared platform in each region. This allows for independent development and deployment.
*   **Granular Regional Control:** A `map(bool)` variable allows you to enable or disable product stacks on a per-region basis, providing fine-grained control over your global footprint.
*   **Global Traffic Management:** A single CloudFront distribution sits in front of the regional ALBs, routing users to the nearest healthy region.
*   **Infrastructure as Code:** The entire infrastructure is defined using Terraform, enabling consistent and repeatable deployments.

## Project Structure

The project is organized into the following directories:

*   `environments/dev/main.tf`: The **Terraform Root**. This is the primary entrypoint that defines the shared platform resources for each AWS region and instantiates the application modules.
*   `modules/microservice`: A generic, reusable Terraform module for deploying a single microservice to ECS.
*   `apps/xelta`: An application module that defines the services for the Xelta product. This module is a consumer of the regional shared platforms.
*   `environments/dev/variables.tf`: Defines the input variables for the environment.
*   `environments/dev/variables.tfvars`: Contains the environment-specific variable values.

## How it Works: The Multi-Region Shared Platform

The `environments/dev/main.tf` file defines the shared platform for each region (`us-east-1`, `eu-central-1`, `ap-south-1`). Each regional platform includes:

*   A single **ECS Cluster** (`aws_ecs_cluster`).
*   A single **Application Load Balancer** (`aws_lb`).
*   An **ALB Listener** (`aws_lb_listener`).

Each application module, like `apps/xelta`, is then instantiated once per region. The `lookup` function is used with a map variable to determine whether the application should be deployed in that specific region.

## Configuration

### 1. Set Up the Terraform Backend

The Terraform state is stored remotely in an S3 bucket. You need to create an S3 bucket and a DynamoDB table (for state locking) in your AWS account.

Once created, update the `backend "s3"` block in `environments/dev/main.tf`.

### 2. Configure Regional Deployments

In `environments/dev/variables.tfvars`, you can control which regions the Xelta application is deployed to using the `xelta_region_config` map:

```terraform
# environments/dev/variables.tfvars

# Deploy Xelta ONLY to US and EU. Do not deploy to AP.
xelta_region_config = {
  "us-east-1"    = true
  "eu-central-1" = true
  "ap-south-1"   = false
}
```
This provides granular control over your application's presence in each region.

## Manual Deployment

To deploy the infrastructure manually, follow these steps:

1.  **Navigate to the Environment Directory (Terraform Root):**
    ```bash
    cd environments/dev
    ```

2.  **Initialize Terraform:**
    ```bash
    terraform init
    ```

3.  **Plan the Deployment:**
    Terraform will automatically use the `variables.tfvars` file in the current directory.
    ```bash
    terraform plan
    ```

4.  **Apply the Changes:**
    ```bash
    terraform apply --auto-approve
    ```
