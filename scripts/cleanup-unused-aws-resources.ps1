#Requires -Version 5.1
# Lists unused AWS load balancers after KGateway migration.
param(
  [string]$Region = "us-east-1",
  [switch]$DeleteLegacyAlbs
)

$ErrorActionPreference = "Stop"

Write-Host "=== Expected Load Balancers ===" -ForegroundColor Green
Write-Host "  KEEP: KGateway NLB (k8s-kgateway* or api-gateway service)"
Write-Host "  KEEP: ArgoCD NLB (temporary, until ClusterIP migration)"
Write-Host "  DELETE: ai-travel-alb-prod, k8s-aitravel-* ALBs"
Write-Host ""

Write-Host "=== All Load Balancers ===" -ForegroundColor Yellow
$lbs = aws elbv2 describe-load-balancers --region $Region --output json | ConvertFrom-Json
$keepPatterns = @("k8s-kgateway", "k8s-argocd-argocdse", "kgateway")
foreach ($lb in $lbs.LoadBalancers) {
  $keepMatch = $false
  foreach ($prefix in $keepPatterns) {
    if ($lb.LoadBalancerName -like "$prefix*") { $keepMatch = $true; break }
  }
  if ($keepMatch) {
    Write-Host "KEEP: $($lb.LoadBalancerName) ($($lb.Type))" -ForegroundColor Green
  } else {
    Write-Host "DELETE: $($lb.LoadBalancerName) ($($lb.Type)) -> $($lb.DNSName)" -ForegroundColor Red
    if ($DeleteLegacyAlbs -and $lb.Type -eq "application") {
      aws elbv2 delete-load-balancer --load-balancer-arn $lb.LoadBalancerArn --region $Region
      Write-Host "  Deleted $($lb.LoadBalancerName)" -ForegroundColor Green
    }
  }
}

Write-Host "`nRemove Terraform ALB: terraform apply -var-file=environments/prod.tfvars (enable_legacy_alb=false)" -ForegroundColor Cyan
Write-Host "Remove legacy Ingress ALBs: .\scripts\cleanup-legacy-ingress.ps1" -ForegroundColor Cyan
