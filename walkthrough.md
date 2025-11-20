# Terraform Restructuring Walkthrough

I have restructured the Terraform codebase to support an organization-wide scale and added a destroy switch.

## New Directory Structure

The codebase is now organized as follows:

```
.
├── modules/                  # Shared modules
│   ├── xelta_regional_stack/ # [NEW] Encapsulates the regional infrastructure logic
│   ├── vpc/
│   ├── ...
├── teams/                    # [NEW] Team-specific infrastructure
│   ├── xelta/                # Xelta application infrastructure
│   │   ├── main.tf           # Main configuration calling the regional stack
│   │   ├── variables.tf      # Variables including enable_infrastructure
│   │   ├── environments/     # Environment-specific configs (dev, prod, uat)
│   │   ├── lambda/           # Lambda functions
│   │   └── ...
```

## Key Changes

1.  **Organization-Wide Structure**: Created `teams/xelta` to house the infrastructure for the Xelta team. Other teams can have their own folders under `teams/`.
2.  **Modularization**: Extracted the repeated regional logic from `main.tf` into a new module `modules/xelta_regional_stack`. This reduces duplication and makes the code cleaner.
3.  **Destroy Switch**: Added a new variable `enable_infrastructure` (boolean).
    *   When set to `true` (default), resources are created.
    *   When set to `false`, all resources (regional stacks, WAF, CDN) are destroyed (count = 0).
    *   You can control this via `tfvars`.

## How to Use

1.  **Navigate to the team folder**:
    ```bash
    cd teams/xelta
    ```

2.  **Initialize Terraform**:
    ```bash
    terraform init -backend-config=environments/dev/dev.tfbackend
    ```

3.  **Plan/Apply**:
    ```bash
    terraform apply -var-file=environments/dev/variables.tfvars
    ```

4.  **Destroy using the Switch**:
    To destroy the infrastructure without running `terraform destroy` (which destroys the state too), you can set the flag to false:
    
    Edit `environments/dev/variables.tfvars`:
    ```hcl
    enable_infrastructure = false
    ```
    
    Then run:
    ```bash
    terraform apply -var-file=environments/dev/variables.tfvars
    ```
