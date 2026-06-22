#Requires -Version 5.1
# Sync all ArgoCD applications in dependency order
$ErrorActionPreference = "Stop"
$kubectl = Join-Path $env:USERPROFILE ".local\bin\kubectl.exe"
if (-not (Test-Path $kubectl)) { $kubectl = "kubectl" }

function Sync-App($Name) {
  Write-Host "Syncing $Name ..." -ForegroundColor Cyan
  & $kubectl patch application $Name -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' | Out-Null
  & $kubectl patch application $Name -n argocd --type merge -p '{"operation":{"sync":{"revision":"HEAD","prune":true}}}' 2>$null
  Start-Sleep -Seconds 8
  $status = & $kubectl get application $Name -n argocd -o jsonpath='{.status.sync.status}/{.status.health.status}'
  Write-Host "  -> $status" -ForegroundColor $(if ($status -like 'Synced*Healthy*') { 'Green' } else { 'Yellow' })
}

Write-Host "==> Step 1: AppProject" -ForegroundColor Cyan
& $kubectl apply -f "D:\downloads\AI-Travel-Planner-Microservices-main\planmyjourney-gitops\argocd-apps\projects\planmyjourney.yaml"

Write-Host "==> Step 2: Secrets from AWS" -ForegroundColor Cyan
& "D:\downloads\AI-Travel-Planner-Microservices-main\planmyjourney-gitops\scripts\sync-secrets-from-aws.ps1"

Write-Host "==> Step 3: Envoy Gateway controller" -ForegroundColor Cyan
helm repo add envoy https://github.com/envoyproxy/gateway 2>$null
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm --version v1.2.4 --namespace envoy-gateway-system --create-namespace --wait --timeout 8m 2>&1 | Select-Object -Last 5

Write-Host "==> Step 4: ArgoCD sync order" -ForegroundColor Cyan
Sync-App "planmyjourney-app-of-apps"
Sync-App "prod-envoy-gateway"
Sync-App "prod-gateway-routes"

$services = @('prod-frontend','prod-ai-service','prod-user-service','prod-travel-service','prod-utility-service',
              'dev-frontend','dev-ai-service','dev-user-service','dev-travel-service','dev-utility-service')
foreach ($app in $services) { Sync-App $app }

Write-Host ""
Write-Host "==> Final status" -ForegroundColor Cyan
& $kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status
& $kubectl get pods -n prod
& $kubectl get pods -n dev
