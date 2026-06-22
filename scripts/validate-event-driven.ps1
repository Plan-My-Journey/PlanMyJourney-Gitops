#Requires -Version 5.1
# Validate event-driven platform components (read-only checks).
$ErrorActionPreference = "Continue"
$kubectl = Join-Path $env:USERPROFILE ".local\bin\kubectl.exe"
if (-not (Test-Path $kubectl)) { $kubectl = "kubectl" }

Write-Host "==> Terraform validate" -ForegroundColor Cyan
Push-Location "D:\downloads\AI-Travel-Planner-Microservices-main\planmyjourney-terraform"
terraform init -backend=false 2>&1 | Out-Null
terraform validate 2>&1
Pop-Location

Write-Host "`n==> Helm lint (ai-worker)" -ForegroundColor Cyan
helm lint "D:\downloads\AI-Travel-Planner-Microservices-main\planmyjourney-gitops\helm-charts\ai-worker" 2>&1

Write-Host "`n==> Cluster checks" -ForegroundColor Cyan
& $kubectl get crd scaledobjects.keda.sh 2>&1
& $kubectl get crd nodepools.karpenter.sh 2>&1
& $kubectl get scaledobject -A 2>&1
& $kubectl get nodepool -A 2>&1
& $kubectl get applications -n argocd -l app.kubernetes.io/name 2>&1

Write-Host "`n==> AWS checks" -ForegroundColor Cyan
aws sqs get-queue-url --queue-name ai-travel-prod-ai-jobs --region us-east-1 2>&1
aws dynamodb describe-table --table-name ai-travel-prod-ai-jobs --region us-east-1 --query "Table.TableStatus" 2>&1

Write-Host "`nDone." -ForegroundColor Green
