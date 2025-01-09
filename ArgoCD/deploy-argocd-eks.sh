#!/bin/bash

# Set variables
CLUSTER_NAME="my-eks-cluster"
REGION="us-east-1"
NAMESPACE="argocd"
ARGOCD_VERSION="v2.9.7"

# Step 1: Create an EKS Cluster (if not already created)
create_eks_cluster() {
  echo "Creating EKS Cluster..."
  eksctl create cluster --name "$CLUSTER_NAME" --region "$REGION" --nodes 2 --nodegroup-name linux-nodes --node-type t3.medium --managed
}

# Step 2: Update kubeconfig to point to the EKS Cluster
update_kubeconfig() {
  echo "Updating kubeconfig..."
  aws eks --region "$REGION" update-kubeconfig --name "$CLUSTER_NAME"
}

# Step 3: Install kubectl, helm, and argocd if not installed
install_tools() {
  echo "Checking for kubectl..."
  if ! command -v kubectl &> /dev/null; then
    echo "kubectl not found, installing..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl && sudo mv kubectl /usr/local/bin/
  fi

  echo "Checking for helm..."
  if ! command -v helm &> /dev/null; then
    echo "helm not found, installing..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  fi

  echo "Checking for argocd..."
  if ! command -v argocd &> /dev/null; then
    echo "argocd not found, installing..."
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/$ARGOCD_VERSION/argocd-linux-amd64
    chmod +x argocd-linux-amd64 && sudo mv argocd-linux-amd64 /usr/local/bin/argocd
  fi
}

# Step 4: Install ArgoCD on EKS Cluster
install_argocd() {
  echo "Installing ArgoCD..."
  kubectl create namespace "$NAMESPACE"

  # Install ArgoCD using Helm
  helm repo add argo https://argoproj.github.io/argo-helm
  helm repo update
  helm install argocd argo/argo-cd --namespace "$NAMESPACE" --version "$ARGOCD_VERSION"

  # Wait for ArgoCD Pods to be ready
  echo "Waiting for ArgoCD to be ready..."
  kubectl wait --namespace "$NAMESPACE" --for=condition=available --timeout=600s deployment/argocd-server
}

# Step 5: Expose ArgoCD Server using LoadBalancer Service
expose_argocd() {
  echo "Exposing ArgoCD Server..."
  kubectl patch svc argocd-server -n "$NAMESPACE" -p '{"spec": {"type": "LoadBalancer"}}'

  # Wait for the external IP
  echo "Waiting for the LoadBalancer IP..."
  while true; do
    ARGOCD_IP=$(kubectl get svc argocd-server -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    if [ -n "$ARGOCD_IP" ]; then
      break
    fi
    sleep 10
  done
  echo "ArgoCD is accessible at: http://$ARGOCD_IP"
}

# Step 6: Get ArgoCD Initial Admin Password
get_argocd_password() {
  echo "Fetching ArgoCD initial admin password..."
  PASSWORD=$(kubectl get secret -n "$NAMESPACE" argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
  echo "Username: admin"
  echo "Password: $PASSWORD"
}

# Main function to run all steps
main() {
  create_eks_cluster
  update_kubeconfig
  install_tools
  install_argocd
  expose_argocd
  get_argocd_password
}

# Run the main function
main
