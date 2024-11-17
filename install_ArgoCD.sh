#!/bin/bash

# Install ArgoCD

# Create ArgoCD Namespace.
kubectl create namespace argocd

# Install ArgoCD in the Cluster.
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Expose ArgoCD service to External access,
# by patching the service as LoadBalancer type:
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Wait for the LoadBalancer IP/DNS to be assigned (this may take a few moments)
echo "Waiting for ArgoCD LoadBalancer IP/DNS..."
sleep 35  # Adjust as needed based on your cloud provider's response time.

# Capture the LoadBalancer DNS name (or IP)
ARGOCD_SERVER=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Print the ArgoCD password as terminal output 
# for the login UI of ArgoCD.
ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d)

# Log in to ArgoCD automatically
argocd login "$ARGOCD_SERVER" --username admin --password "$ARGOCD_PASSWORD" --insecure

# Confirm login success
echo "Logged in to ArgoCD at $ARGOCD_SERVER with user 'admin'"

