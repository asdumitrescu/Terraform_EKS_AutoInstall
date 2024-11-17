#!/bin/bash
set -e

# Timeout settings
TIMEOUT_SECONDS=300
WAIT_SECONDS=10

# Load environment variables
if [ -f "config/.env" ]; then
    source config/.env
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Setup logging
exec 1> >(tee -a cleanup.log) 2>&1

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%dT%H:%M:%S%z')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%dT%H:%M:%S%z')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%dT%H:%M:%S%z')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%dT%H:%M:%S%z')] INFO: $1${NC}"
}

cleanup_load_balancers() {
    log "Starting LoadBalancer cleanup..."
    
    info "Fetching LoadBalancer services..."
    services=$(kubectl get svc --all-namespaces --field-selector type=LoadBalancer -o json | jq -r '.items[] | .metadata.namespace + "/" + .metadata.name')
    
    if [ -z "$services" ]; then
        info "No LoadBalancer services found"
        return
    fi
    
    echo "$services" | while read -r svc; do
        if [ ! -z "$svc" ]; then
            namespace=$(echo $svc | cut -d'/' -f1)
            name=$(echo $svc | cut -d'/' -f2)
            info "Deleting LoadBalancer service: $namespace/$name"
            kubectl delete svc $name -n $namespace || warn "Failed to delete service $namespace/$name"
        fi
    done
}

cleanup_aws_iam() {
    log "Starting AWS IAM cleanup..."
    
    info "Getting cluster OIDC provider URL..."
    OIDC_PROVIDER_URL=$(aws eks describe-cluster --name $EKS_CLUSTER_NAME --region $AWS_REGION --query "cluster.identity.oidc.issuer" --output text | sed 's/https:\/\///')
    ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
    
    info "Looking for IAM roles associated with cluster $EKS_CLUSTER_NAME..."
    roles=$(aws iam list-roles --query "Roles[?contains(RoleName, '${EKS_CLUSTER_NAME}')].RoleName" --output text)
    
    if [ ! -z "$roles" ]; then
        for role in $roles; do
            info "Processing role: $role"
            policies=$(aws iam list-attached-role-policies --role-name $role --query "AttachedPolicies[].PolicyArn" --output text)
            
            if [ ! -z "$policies" ]; then
                for policy in $policies; do
                    info "Detaching policy $policy from role $role"
                    aws iam detach-role-policy --role-name $role --policy-arn $policy || warn "Failed to detach policy"
                done
            fi
            
            info "Deleting role: $role"
            aws iam delete-role --role-name $role || warn "Failed to delete role"
        done
    else
        info "No IAM roles found for cluster $EKS_CLUSTER_NAME"
    fi
    
    if [ ! -z "$OIDC_PROVIDER_URL" ]; then
        OIDC_PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER_URL}"
        info "Deleting OIDC provider: $OIDC_PROVIDER_ARN"
        aws iam delete-open-id-connect-provider --open-id-connect-provider-arn $OIDC_PROVIDER_ARN || warn "Failed to delete OIDC provider"
    fi
}

cleanup_kubernetes() {
    log "Starting Kubernetes cleanup..."
    
    info "Removing ArgoCD installation..."
    helm list -n argocd | grep -q "argocd" && {
        helm uninstall argocd -n argocd || warn "Failed to uninstall ArgoCD"
    }
    
    info "Deleting ArgoCD namespace..."
    kubectl get namespace argocd &>/dev/null && {
        kubectl delete namespace argocd --timeout=60s || warn "Failed to delete ArgoCD namespace"
    }
    
    info "Removing AWS Load Balancer Controller..."
    kubectl get deployment -n kube-system aws-load-balancer-controller &>/dev/null && {
        kubectl delete deployment aws-load-balancer-controller -n kube-system || warn "Failed to delete AWS Load Balancer Controller"
    }
    
    info "Looking for feature namespaces..."
    feature_ns=$(kubectl get ns -o name | grep "feature-" || true)
    if [ ! -z "$feature_ns" ]; then
        for ns in $feature_ns; do
            info "Deleting namespace: $ns"
            kubectl delete $ns --timeout=60s || warn "Failed to delete namespace $ns"
        done
    else
        info "No feature namespaces found"
    fi
    
    info "Cleaning up custom namespaces..."
    kubectl get namespace button-left-menu &>/dev/null && {
        kubectl delete namespace button-left-menu --timeout=60s || warn "Failed to delete button-left-menu namespace"
    }
    
    info "Removing cluster roles and bindings..."
    kubectl get clusterrole preview-manager-cluster-role &>/dev/null && {
        kubectl delete clusterrole preview-manager-cluster-role || warn "Failed to delete cluster role"
    }
    kubectl get clusterrolebinding preview-manager-cluster-rolebinding &>/dev/null && {
        kubectl delete clusterrolebinding preview-manager-cluster-rolebinding || warn "Failed to delete cluster role binding"
    }
}

cleanup_aws_resources() {
    log "Starting AWS resources cleanup..."
    
    info "Looking for Load Balancers..."
    albs=$(aws elbv2 describe-load-balancers --region $AWS_REGION --query 'LoadBalancers[?contains(DNSName, `k8s`)].[LoadBalancerArn]' --output text)
    
    if [ ! -z "$albs" ]; then
        for alb in $albs; do
            info "Deleting Load Balancer: $alb"
            aws elbv2 delete-load-balancer --load-balancer-arn $alb --region $AWS_REGION || warn "Failed to delete Load Balancer"
            sleep 5  # Wait a bit for AWS to process
        done
    else
        info "No Load Balancers found"
    fi
    
    info "Looking for Target Groups..."
    tgs=$(aws elbv2 describe-target-groups --region $AWS_REGION --query 'TargetGroups[?contains(TargetGroupName, `k8s`)].[TargetGroupArn]' --output text)
    
    if [ ! -z "$tgs" ]; then
        for tg in $tgs; do
            info "Deleting Target Group: $tg"
            aws elbv2 delete-target-group --target-group-arn $tg --region $AWS_REGION || warn "Failed to delete Target Group"
        done
    else
        info "No Target Groups found"
    fi
}

main() {
    log "Starting cleanup process..."
    
    info "Verifying AWS credentials..."
    if ! aws sts get-caller-identity &>/dev/null; then
        error "AWS credentials not configured properly"
        exit 1
    fi
    
    info "Verifying cluster access..."
    if ! kubectl get nodes &>/dev/null; then
        error "Cannot access Kubernetes cluster"
        exit 1
    fi
    
    cleanup_load_balancers
    info "Waiting for LoadBalancer cleanup to complete..."
    sleep 10
    
    cleanup_kubernetes
    info "Waiting for Kubernetes cleanup to complete..."
    sleep 10
    
    cleanup_aws_resources
    info "Waiting for AWS resources cleanup to complete..."
    sleep 10
    
    cleanup_aws_iam
    aws iam detach-role-policy --role-name terraform-eks-demo-preview-manager --policy-arn arn:aws:iam::992382595781:policy/terraform-eks-demo-alb-controller-policy
    log "Cleanup completed successfully!"
    log "You can now proceed with 'terraform destroy'"
}

# Ask for confirmation
echo -e "${YELLOW}This will remove all resources from the cluster and related AWS resources."
echo -e "Are you sure you want to continue? (yes/no)${NC}"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    main
else
    log "Cleanup cancelled"
    exit 0
fi


