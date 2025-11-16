# Xelta Infrastructure

This repository contains the Terraform code to provision a secure, scalable, and multi-region infrastructure on AWS for the Xelta project. The infrastructure is designed with a **Multi-Region Shared Platform** model.

## Project Philosophy

*   **Multi-Region Shared Platform:** Core infrastructure resources, such as the ECS Cluster and Application Load Balancer (ALB), are defined once **per region** in the root `main.tf`. This provides high availability and reduces cost and management complexity within each region.
*   **Product-Based Architecture:** Each product (e.g., Xelta) is a self-contained application module that "plugs into" the shared platform in each region. This allows for independent development and deployment.
*   **Product Kill Switch:** A boolean flag (`enable_xelta`) can enable or disable an entire product stack across all regions without affecting the shared platforms or other running applications.
*   **Global Traffic Management:** A single CloudFront distribution sits in front of the regional ALBs, routing users to the nearest healthy region.
*   **Infrastructure as Code:** The entire infrastructure is defined using Terraform, enabling consistent and repeatable deployments.

## Project Structure

The project is organized into the following directories:

*   `main.tf`: The root module that defines the shared platform resources for each AWS region.
*   `modules/microservice`: A generic, reusable Terraform module for deploying a single microservice to ECS.
*   `apps/xelta`: An application module that defines the services for the Xelta product. This module is a consumer of the regional shared platforms.
*   `environments/dev`: Contains the environment-specific variables (`variables.tfvars`).

## How it Works: The Multi-Region Shared Platform

The root `main.tf` file defines the shared platform for each region (`us-east-1`, `eu-central-1`, `ap-south-1`). Each regional platform includes:

*   A single **ECS Cluster** (`aws_ecs_cluster`).
*   A single **Application Load Balancer** (`aws_lb`).
*   An **ALB Listener** (`aws_lb_listener`).

Each application module, like `apps/xelta`, is then instantiated once per region and passed the corresponding regional platform resources. The application module defines its own:

*   **ECS Services** (`aws_ecs_service`).
*   **Target Groups** (`aws_lb_target_group`).
*   **Listener Rules** (`aws_lb_listener_rule`) to attach to the shared regional listener.

This model allows multiple applications to share the same cluster and ALB within each region, reducing costs and operational overhead while maintaining a global footprint.

## Configuration

### 1. Set Up the Terraform Backend

The Terraform state is stored remotely in an S3 bucket. You need to create an S3 bucket and a DynamoDB table (for state locking) in your AWS account.

Once created, update the `backend "s3"` block in the root `main.tf` with your bucket name, desired key, and DynamoDB table name.

### 2. Configure Environment Variables

Navigate to `environments/dev/` and edit the `variables.tfvars` file.

The most important variable is the "kill switch":

*   `enable_xelta`: Set to `true` to deploy the Xelta stack, or `false` to destroy it.

## Manual Deployment

To deploy the infrastructure manually, follow these steps:

1.  **Navigate to the Project Root Directory:**
    ```bash
    cd /path/to/your/project
    ```

2.  **Initialize Terraform:**
    ```bash
    terraform init
    ```

3.  **Plan the Deployment:**
    You must specify the variables file from the correct environment.
    ```bash
    terraform plan -var-file=environments/dev/variables.tfvars
    ```

4.  **Apply the Changes:**
    ```bash
    terraform apply -var-file=environments/dev/variables.tfvars --auto-approve
    ```
