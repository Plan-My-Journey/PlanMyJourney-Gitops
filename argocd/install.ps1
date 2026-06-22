#Requires -Version 5.1
$ErrorActionPreference = "Stop"
$kubectl = Join-Path $env:USERPROFILE ".local\bin\kubectl.exe"
if (-not (Test-Path $kubectl)) { $kubectl = "kubectl" }

$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

Write-Host "==> Adding ArgoCD Helm repo" -ForegroundColor Cyan
helm repo add argo https://argoproj.github.io/argo-helm 2>$null
helm repo update

Write-Host "==> Installing ArgoCD into namespace argocd" -ForegroundColor Cyan
helm upgrade --install argocd argo/argo-cd `
  --namespace argocd `
  --create-namespace `
  --version 7.7.12 `
  -f argocd/values.yaml `
  --wait `
  --timeout 10m

Write-Host "==> Waiting for argocd-server" -ForegroundColor Cyan
& $kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

$passB64 = & $kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>$null
if ($passB64) {
  $pass = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($passB64))
  Write-Host ""
  Write-Host "ArgoCD admin password: $pass" -ForegroundColor Green
}

Write-Host ""
Write-Host "Open ArgoCD UI:" -ForegroundColor Yellow
Write-Host "  Option A (recommended now): run in a new terminal:" -ForegroundColor White
Write-Host "    kubectl port-forward svc/argocd-server -n argocd 8080:443" -ForegroundColor Cyan
Write-Host "    Then open https://localhost:8080  (user: admin, accept self-signed cert)" -ForegroundColor Cyan
Write-Host "  Option B (public LB, may take 2-3 min):" -ForegroundColor White
& $kubectl get svc argocd-server -n argocd
