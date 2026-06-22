#!/usr/bin/env bash
set -euo pipefail

echo "==> Adding ArgoCD Helm repo"
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

echo "==> Installing ArgoCD"
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --version 7.7.12 \
  -f argocd/values.yaml \
  --wait \
  --timeout 10m

echo "==> Waiting for ArgoCD server"
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

echo "==> Initial admin password"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo

echo "==> ArgoCD server URL options"
echo "1) Port-forward (local): kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   Open https://localhost:8080  user=admin"
echo "2) LoadBalancer: kubectl get svc argocd-server -n argocd"
