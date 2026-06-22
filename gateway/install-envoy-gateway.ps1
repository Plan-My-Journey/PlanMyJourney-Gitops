#Requires -Version 5.1
# Install Envoy Gateway (KGateway provider) on EKS
$ErrorActionPreference = "Stop"
$kubectl = Join-Path $env:USERPROFILE ".local\bin\kubectl.exe"
if (-not (Test-Path $kubectl)) { $kubectl = "kubectl" }

Write-Host "==> Installing Envoy Gateway v1.2.4" -ForegroundColor Cyan
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm `
  --version v1.2.4 `
  --namespace envoy-gateway-system `
  --create-namespace `
  --wait `
  --timeout 10m

Write-Host "==> Waiting for Envoy Gateway controller" -ForegroundColor Cyan
& $kubectl wait --for=condition=available deployment/envoy-gateway -n envoy-gateway-system --timeout=300s

Write-Host "==> GatewayClass created by Helm:" -ForegroundColor Green
& $kubectl get gatewayclass

Write-Host ""
Write-Host "Next: sync prod-envoy-gateway and prod-gateway-routes in ArgoCD" -ForegroundColor Yellow
Write-Host "NLB hostname appears after Gateway sync:" -ForegroundColor Yellow
Write-Host "  kubectl get gateway api-gateway -n gateway-system" -ForegroundColor Cyan
