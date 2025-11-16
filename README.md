# Xelta Infrastructure

This repository contains the Terraform code to provision a secure, scalable, and production-ready infrastructure on AWS for the Xelta project. The infrastructure is designed with a **Product-Based Architecture** using a **Shared Platform** model.

## Project Philosophy

*   **Shared Platform:** Core infrastructure resources, such as the ECS Cluster and Application Load Balancer (ALB), are defined once at the environment level. This reduces cost and simplifies management.
*   **Product-Based Architecture:** Each product (e.g., Xelta) is a self-contained application module that "plugs into" the shared platform. This allows for independent development and deployment.
*   **Product Kill Switch:** A boolean flag can enable or disable an entire product stack without affecting the shared platform or other running applications.
*   **Zero-Trust Networking:** No component trusts another by default. Access is granted via explicit security group rules.
*   **Private by Default:** All ECS tasks reside in private subnets with no direct internet access.
*   **Infrastructure as Code:** The entire infrastructure is defined using Terraform, enabling consistent and repeatable deployments.

## Project Structure

The project is organized into the following directories:

*   `modules/microservice`: A generic, reusable Terraform module for deploying a single microservice to ECS.
*   `apps/xelta`: An application module that defines all the services for the Xelta product (e.g., frontend, backend). This module is a consumer of the shared platform.
*   `environments/dev`: Contains the root configuration for the `dev` environment, including the **Shared Platform** resources.

## How it Works: The Shared Platform

The `environments/dev/main.tf` file defines the shared platform, which includes:

*   A single **ECS Cluster** (`aws_ecs_cluster`).
*   A single **Application Load Balancer** (`aws_lb`).
*   An **ALB Listener** (`aws_lb_listener`) that listens for incoming traffic.

Each application module, like `apps/xelta`, then defines its own:

*   **ECS Services** (`aws_ecs_service`).
*   **Target Groups** (`aws_lb_target_group`).
*   **Listener Rules** (`aws_lb_listener_rule`) to attach to the shared listener and route traffic to its target groups based on path patterns (e.g., `/xelta/*`).

This model allows multiple applications to share the same cluster and ALB, reducing costs and operational overhead.

## Configuration

### 1. Set Up the Terraform Backend

The Terraform state is stored remotely in an S3 bucket. You need to create an S3 bucket and a DynamoDB table (for state locking) in your AWS account.

Once created, update the `backend "s3"` block in `environments/dev/main.tf` with your bucket name, desired key, and DynamoDB table name.

### 2. Configure Environment Variables

Navigate to `environments/dev/` and edit the `variables.tfvars` file.

The most important variable is the "kill switch":

*   `enable_xelta`: Set to `true` to deploy the Xelta stack, or `false` to destroy it.

## How to Use the Kill Switch

In your `environments/dev/variables.tfvars` file:

To deploy the Xelta application:
```
enable_xelta = true
```

To destroy the Xelta application stack:
```
enable_xelta = false
```
When you apply this change, Terraform will destroy only the Xelta-specific resources (services, target groups, listener rules), leaving the shared platform and any other applications untouched.

## Manual Deployment

To deploy the infrastructure manually, follow these steps:

1.  **Navigate to the Environment Directory:**
    ```bash
    cd environments/dev
    ```

2.  **Initialize Terraform:**
    ```bash
    terraform init
    ```

3.  **Plan the Deployment:**
    ```bash
    terraform plan
    ```

4.  **Apply the Changes:**
    ```bash
    terraform apply --auto-approve
    ```
