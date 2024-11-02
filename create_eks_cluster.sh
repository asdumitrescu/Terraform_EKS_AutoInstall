#!/bin/bash

# Set variables
CLUSTER_NAME="terraform-eks-demo"
AWS_REGION="us-east-1"

# Step 1: Apply the full Terraform configuration
echo "Applying the full Terraform configuration..."
terraform apply -auto-approve

# Step 2: Wait for the EKS cluster to be ready
echo "Waiting for EKS cluster to become active..."
aws eks wait cluster-active --name $CLUSTER_NAME --region $AWS_REGION

# Step 3: Install AWS Load Balancer Controller using Helm

echo "Installing AWS Load Balancer Controller using Helm..."

# Retrieve the IAM role ARN from Terraform outputs
ALB_CONTROLLER_ROLE_ARN=$(terraform output -raw alb_controller_role_arn)

# Create Kubernetes namespace (if not already created)
kubectl create namespace kube-system 2>/dev/null || true

# Create Kubernetes service account with the IAM role annotation
kubectl create serviceaccount aws-load-balancer-controller -n kube-system 2>/dev/null || true
kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system \
eks.amazonaws.com/role-arn=$ALB_CONTROLLER_ROLE_ARN --overwrite

# Add the EKS Helm chart repository
helm repo add eks https://aws.github.io/eks-charts

# Update Helm repositories
helm repo update

# Get the VPC ID from Terraform outputs
VPC_ID=$(terraform output -raw vpc_id)

# Install the AWS Load Balancer Controller
helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$AWS_REGION \
  --set vpcId=$VPC_ID

# Step 4: Tag subnets for load balancer auto-discovery
echo "Tagging subnets for load balancer auto-discovery..."

# Get the public subnet IDs from Terraform outputs
PUBLIC_SUBNET_IDS=$(terraform output -json public_subnet_ids | jq -r '.[]')

# Tag each public subnet
for SUBNET_ID in $PUBLIC_SUBNET_IDS; do
  echo "Tagging public subnet $SUBNET_ID"
  aws ec2 create-tags --resources $SUBNET_ID --tags Key=kubernetes.io/role/elb,Value=1
done

# Get the private subnet IDs from Terraform outputs
PRIVATE_SUBNET_IDS=$(terraform output -json private_subnet_ids | jq -r '.[]')



# Step 1: Retrieve OIDC provider ARN
OIDC_ARN=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.identity.oidc.issuer" --output text | sed 's/^https:\/\///')

# Step 2: Define the dynamic IAM role name
ROLE_NAME="${CLUSTER_NAME}-alb-controller-role"

# Step 3: Create the trust-policy.json file dynamically
cat <<EOF > trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "$OIDC_ARN"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "$OIDC_ARN:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }
  ]
}
EOF

# Step 4: Create or update the IAM role with this trust policy
aws iam create-role --role-name $ROLE_NAME --assume-role-policy-document file://trust-policy.json || \
aws iam update-assume-role-policy --role-name $ROLE_NAME --policy-document file://trust-policy.json

