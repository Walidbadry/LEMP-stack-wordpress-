#!/bin/bash

# Start Minikube
echo "--------------------Starting Minikube--------------------"
minikube start

# Create Namespace
echo "--------------------Create Argocd Namespace--------------------"
kubectl create ns argocd || true  # Avoid error if namespace already exists

# Deploy ArgoCD
echo "--------------------Deploying ArgoCD--------------------"
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD pods to start
echo "--------------------Waiting 1m for the pods to start--------------------"
sleep 1m

# Check if all ArgoCD pods are running
echo "--------------------Checking ArgoCD pod status--------------------"
kubectl get pods -n argocd

# Change ArgoCD service to NodePort
echo "--------------------Changing ArgoCD service to NodePort--------------------"
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'

# Retrieve ArgoCD URL
echo "--------------------ArgoCD URL--------------------"
minikube service -n argocd argocd-server --url

# Retrieve ArgoCD UI Password
echo "--------------------ArgoCD UI Password--------------------"
echo "Username: admin"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode

# Save the password to a file
echo "Saving ArgoCD password to argo-pass.txt"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode > argo-pass.txt
