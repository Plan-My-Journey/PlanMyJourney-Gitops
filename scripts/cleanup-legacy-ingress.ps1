#Requires -Version 5.1
# Remove legacy ai-travel Ingress resources that provision unused ALBs.
# Verified safe: all ai-travel deployments are scaled to 0 (not serving traffic).
param(
  [switch]$DeleteNamespace,
  [switch]$Force
)

$ErrorActionPreference = "Stop"
$kubectl = Join-Path $env:USERPROFILE ".local\bin\kubectl.exe"
if (-not (Test-Path $kubectl)) { $kubectl = "kubectl" }

Write-Host "=== Legacy Ingress Inventory ===" -ForegroundColor Cyan
& $kubectl get ingress -n ai-travel -o wide 2>&1

Write-Host "`n=== ai-travel Deployment Replicas ===" -ForegroundColor Cyan
& $kubectl get deploy -n ai-travel -o custom-columns=NAME:.metadata.name,READY:.status.readyReplicas,DESIRED:.spec.replicas 2>&1

$ready = & $kubectl get deploy -n ai-travel -o jsonpath='{range .items[*]}{.status.readyReplicas}{"\n"}{end}' 2>$null
$hasTraffic = $false
foreach ($r in @($ready -split "`n")) {
  if ($r -and [int]$r -gt 0) { $hasTraffic = $true }
}

if ($hasTraffic -and -not $Force) {
  throw "ai-travel namespace has running pods. Aborting. Use -Force to override."
}

if (-not $Force) {
  $confirm = Read-Host "Delete all Ingress in ai-travel? (yes/no)"
  if ($confirm -ne "yes") { Write-Host "Aborted."; exit 0 }
}

Write-Host "`nDeleting legacy Ingress resources..." -ForegroundColor Yellow
& $kubectl delete ingress --all -n ai-travel --ignore-not-found
Write-Host "Ingress deleted. AWS ALBs will deprovision within ~5 minutes." -ForegroundColor Green

if ($DeleteNamespace) {
  Write-Host "Deleting ai-travel namespace..." -ForegroundColor Yellow
  & $kubectl delete namespace ai-travel --ignore-not-found
}

Write-Host "`nRemaining load balancers (expect only KGateway + ArgoCD NLBs):" -ForegroundColor Cyan
aws elbv2 describe-load-balancers --query "LoadBalancers[*].{Name:LoadBalancerName,Type:Type}" --output table
