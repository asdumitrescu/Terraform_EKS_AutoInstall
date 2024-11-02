
## Terraform EKS Setup with AWS Load Balancer Controller

This repository provides a complete setup for deploying an Amazon EKS cluster with the AWS Load Balancer Controller using Terraform and Helm. The setup includes creating a Virtual Private Cloud (VPC) with public and private subnets, deploying the EKS cluster, and configuring IAM roles necessary for AWS Load Balancer Controller integration.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Clone the Repository](#clone-the-repository)
3. [Configuration](#configuration)
4. [Deployment](#deployment)
5. [Modules](#modules)
6. [IAM Role Setup](#iam-role-setup)
7. [Cleanup](#cleanup)

---

## Prerequisites

- **AWS Account**: You must have an AWS account to deploy the resources.
- **AWS CLI**: Ensure that the AWS CLI is installed and configured with the necessary permissions.
  - [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
  - Configure by running:
    ```bash
    aws configure
    ```
- **Terraform**: Install [Terraform](https://www.terraform.io/downloads.html) to manage infrastructure.
- **kubectl**: Install [kubectl](https://kubernetes.io/docs/tasks/tools/) to interact with the Kubernetes cluster.
- **Helm**: Install [Helm](https://helm.sh/docs/intro/install/) to manage Kubernetes applications.

---

## Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPOSITORY.git
cd YOUR_REPOSITORY
```

---

## Configuration

Before deploying, you may need to modify the `variables.tf` file in each module to adjust configurations like `vpc_cidr`, `public_subnet_cidrs`, and `private_subnet_cidrs`. Ensure the values align with your environment requirements.

For example, in `variables.tf`, you can set:

```hcl
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}
```

---

## Deployment

To deploy the EKS cluster and the AWS Load Balancer Controller, follow these steps:

### Set Variables

Modify the `CLUSTER_NAME` and `AWS_REGION` variables in the `create_eks_cluster.sh` script as needed, or export them as environment variables.

### Run the Setup Script

Execute the setup script to apply the Terraform configurations and install the AWS Load Balancer Controller.

```bash
chmod +x create_eks_cluster.sh
./create_eks_cluster.sh
```

This script will:

1. Retrieve the OIDC provider ARN and create a trust policy for the IAM role used by the AWS Load Balancer Controller.
2. Apply the Terraform configuration to set up the VPC, EKS cluster, node groups, and necessary IAM roles.
3. Install the AWS Load Balancer Controller on the EKS cluster using Helm.

---

## Modules

This project is organized into several Terraform modules for better modularity and reusability:

### 1. VPC Module
   - **Purpose**: Creates a Virtual Private Cloud (VPC) with public and private subnets to host the EKS cluster.
   - **Resources**:
     - VPC
     - Internet Gateway
     - Public and Private Subnets
     - Route Tables and Associations

### 2. EKS Cluster Module
   - **Purpose**: Deploys the Amazon EKS cluster using the configured VPC.
   - **Resources**:
     - EKS Cluster
     - Security Groups and Network Interfaces
   - **Configuration**:
     - Cluster name and region are defined as variables to simplify deployment across different environments.

### 3. EKS Node Group Module
   - **Purpose**: Creates a managed node group for the EKS cluster to provide worker nodes.
   - **Resources**:
     - EKS Node Group
     - Auto-scaling configuration
   - **Configuration**:
     - Node instance type, scaling configurations, and key pairs are defined to manage node resources effectively.

### 4. IAM Module
   - **Purpose**: Manages IAM roles and policies for the AWS Load Balancer Controller and other necessary permissions.
   - **Resources**:
     - IAM Role for AWS Load Balancer Controller
     - IAM Policies
   - **Configuration**:
     - The trust policy is dynamically generated to use the correct OIDC provider ARN for the EKS cluster.

---

## IAM Role Setup

The setup script automatically creates and configures an IAM role for the AWS Load Balancer Controller, including the necessary trust policy.

1. **OIDC Provider**: The script retrieves the OIDC provider ARN from the EKS cluster.
2. **Trust Policy**: A trust policy is created dynamically to allow the Load Balancer Controller to assume the role.

The trust policy (`trust-policy.json`) is automatically generated with the correct OIDC provider ARN.

---

## Optional: Install ArgoCD in EKS Cluster

To install and configure ArgoCD in the EKS cluster, follow these steps:

1. **Create a separate namespace for ArgoCD**:
    ```bash
    kubectl create namespace argocd
    ```

2. **Install ArgoCD**:
    ```bash
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    ```

3. **Expose the ArgoCD service to the outside**:
    ```bash
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
    ```

4. **Get the ArgoCD web URL for login**:
    ```bash
    kubectl get svc argocd-server -n argocd | awk '{print $4}'
    ```

5. **Get the name of the ArgoCD server pod**:
    ```bash
    kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d'/' -f 2
    ```

6. **Log in to ArgoCD with the CLI**:
    ```bash
    argocd login "WEB_URL_THAT_GOT_EARLIER" --insecure
    ```

    Use the web URL obtained in step 4 as the login address.

7. **Log in to the ArgoCD UI**:
    - **Username**: `admin`
    - **Password**: The pod name obtained in step 5.

These steps will set up ArgoCD on your EKS cluster and allow access through both the web UI and the CLI.
---

## Cleanup
In case you applied ArgoCD into your cluster,
before detroying the infrastructure created earlier
you have to remove the load balancer of ArgoCD using the following command
```bash
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "ClusterIP"}}'
```

To remove all deployed resources, run the following command:
```bash
terraform destroy -auto-approve
```

This will delete all resources created by the Terraform configuration, including the VPC, EKS cluster, node groups, and IAM roles.

---
