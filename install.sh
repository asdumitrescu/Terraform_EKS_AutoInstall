#!/bin/bash
# Set variables
CLUSTER_NAME="terraform-eks-demo"
AWS_REGION="us-east-1"

# Step 1: Apply the full Terraform configuration
echo "Applying the full Terraform configuration..."
terraform apply -auto-approve

# Step 2: Wait for the EKS cluster to be active
echo "Waiting for EKS cluster to become active..."
MAX_RETRIES=30  # Maximum number of retries
RETRY_INTERVAL=30  # Interval between retries in seconds
for ((i=1; i<=MAX_RETRIES; i++)); do
  STATUS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.status" --output text)
  if [ "$STATUS" == "ACTIVE" ]; then
    echo "EKS cluster is now active."
    break
  else
    echo "Cluster is not active yet. Retry $i of $MAX_RETRIES..."
    sleep $RETRY_INTERVAL
  fi
done

if [ "$STATUS" != "ACTIVE" ]; then
  echo "EKS cluster did not become active within the expected time. Exiting."
  exit 1
fi

# Step 3: Install AWS Load Balancer Controller using Helm
echo "Installing AWS Load Balancer Controller using Helm..."
# Retrieve the IAM role ARN from Terraform outputs
ALB_CONTROLLER_ROLE_ARN=$(terraform output -raw alb_controller_role_arn)

aws eks update-kubeconfig --name terraform-eks-demo --region us-east-1

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
# Get both public and private subnet IDs
PUBLIC_SUBNET_IDS=$(terraform output -json public_subnet_ids | jq -r '.[]')
PRIVATE_SUBNET_IDS=$(terraform output -json private_subnet_ids | jq -r '.[]')

# Tag public subnets
echo "Tagging public subnets..."
for SUBNET_ID in $PUBLIC_SUBNET_IDS; do
  echo "Tagging public subnet $SUBNET_ID"
  aws ec2 create-tags --resources $SUBNET_ID --tags \
    Key=kubernetes.io/role/elb,Value=1 \
    Key=kubernetes.io/cluster/${CLUSTER_NAME},Value=shared
done

# Tag private subnets
echo "Tagging private subnets..."
for SUBNET_ID in $PRIVATE_SUBNET_IDS; do
  echo "Tagging private subnet $SUBNET_ID"
  aws ec2 create-tags --resources $SUBNET_ID --tags \
    Key=kubernetes.io/role/internal-elb,Value=1 \
    Key=kubernetes.io/cluster/${CLUSTER_NAME},Value=shared
done

# Step 5: Retrieve OIDC provider ARN
OIDC_ARN=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.identity.oidc.issuer" --output text | sed 's/^https:\/\///')

# Step 6: Define the dynamic IAM role name
ROLE_NAME="${CLUSTER_NAME}-alb-controller-role"

# Step 7: Create the trust-policy.json file dynamically
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

# Step 8: Create or update the IAM role with this trust policy
aws iam create-role --role-name $ROLE_NAME --assume-role-policy-document file://trust-policy.json || \
aws iam update-assume-role-policy --role-name $ROLE_NAME --policy-document file://trust-policy.json

# Step 9: Verify subnet tagging
echo "Verifying subnet tags..."
echo "Public subnets:"
for SUBNET_ID in $PUBLIC_SUBNET_IDS; do
  echo "Tags for subnet $SUBNET_ID:"
  aws ec2 describe-tags --filters "Name=resource-id,Values=$SUBNET_ID" --output table
done

echo "Private subnets:"
for SUBNET_ID in $PRIVATE_SUBNET_IDS; do
  echo "Tags for subnet $SUBNET_ID:"
  aws ec2 describe-tags --filters "Name=resource-id,Values=$SUBNET_ID" --output table
done
