### **How to Use This Project**

1.  **Setup & Configure S3 Backend:**
    *   All the necessary files and directories have been created for you.
    *   Open `terraform/environments/dev/region_ap-south-1/main.tf`.
    *   Uncomment and configure the `backend "s3"` block with your S3 bucket details for storing Terraform state.

2.  **Configure Environment Variables:**
    *   Navigate to the environment directory: `cd terraform/environments/dev/region_ap-south-1/`
    *   Copy the example variables file: `cp terraform.tfvars.example terraform.tfvars`
    *   Edit `terraform.tfvars` and fill in the required values:
        *   `parent_zone_id`: The Route 53 Hosted Zone ID for your root domain (e.g., `xelta.com`). You can find this in the AWS Route 53 console.
        *   `ec2_key_name` (Optional): If you need SSH access to the EKS nodes, provide the name of an EC2 Key Pair that exists in the `ap-south-1` region.

3.  **Deploy Infrastructure:**
    *   From the same directory (`terraform/environments/dev/region_ap-south-1/`), initialize Terraform and apply the configuration:
    ```bash
    terraform init
    terraform apply --auto-approve
    ```

4.  **Get Outputs for Kubernetes:**
    *   After the `apply` command succeeds, Terraform will have created the necessary resources. Get the outputs required for the next steps:
    ```bash
    # This will print the WAF ARN
    terraform output waf_arn

    # This will print the ALB's Security Group ID
    terraform output alb_security_group_id
    ```

5.  **Connect `kubectl` to EKS:**
    *   Configure `kubectl` to communicate with your new EKS cluster. The command will be based on the variables you set. For the `dev` environment in `ap-south-1`, it is:
    ```bash
    aws eks update-kubeconfig --region ap-south-1 --name xelta-dev
    ```

6.  **Install AWS Load Balancer Controller:**
    *   The IAM role for the controller has already been created by Terraform. Now, install the controller itself onto your cluster using Helm:
    ```bash
    helm repo add eks https://aws.github.io/eks-charts
    helm repo update
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
      -n kube-system \
      --set clusterName=xelta-dev \
      --set serviceAccount.create=false \
      --set serviceAccount.name=aws-load-balancer-controller
    ```

7.  **Deploy Your Application:**
    *   Open `kubernetes-examples/secure-ingress.yaml`.
    *   Replace the placeholder values for `alb.ingress.kubernetes.io/wafv2-acl-arn` and `alb.ingress.kubernetes.io/security-groups` with the outputs you retrieved in Step 4.
    *   Update the `backend` service names and ports to match your application's Kubernetes services.
    *   Deploy your application and the updated Ingress manifest:
    ```bash
    kubectl apply -f /path/to/your/app-deployment.yaml
    kubectl apply -f kubernetes-examples/secure-ingress.yaml
    ```
    The AWS Load Balancer Controller will now automatically provision an ALB, configured securely with the WAF and security group you created.