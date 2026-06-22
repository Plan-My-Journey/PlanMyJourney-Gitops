#Requires -Version 5.1
# Lists unused AWS resources identified during the security audit.
# Review output before deleting anything.
param(
  [string]$Region = "us-east-1",
  [switch]$DeleteLegacyAlbs
)

$ErrorActionPreference = "Stop"

Write-Host "=== Unused Load Balancers (candidates for deletion) ===" -ForegroundColor Yellow
$lbs = aws elbv2 describe-load-balancers --region $Region --output json | ConvertFrom-Json
$keep = @("k8s-envoygat-envoygat", "k8s-argocd-argocdse")
foreach ($lb in $lbs.LoadBalancers) {
  $keepMatch = $false
  foreach ($prefix in $keep) {
    if ($lb.LoadBalancerName -like "$prefix*") { $keepMatch = $true; break }
  }
  if (-not $keepMatch) {
    Write-Host "DELETE: $($lb.LoadBalancerName) ($($lb.Type)) -> $($lb.DNSName)" -ForegroundColor Red
    if ($DeleteLegacyAlbs) {
      aws elbv2 delete-load-balancer --load-balancer-arn $lb.LoadBalancerArn --region $Region
      Write-Host "  Deleted $($lb.LoadBalancerName)" -ForegroundColor Green
    }
  }
}

Write-Host "`n=== Unattached EBS Volumes ===" -ForegroundColor Yellow
aws ec2 describe-volumes --region $Region --filters "Name=status,Values=available" `
  --query "Volumes[*].{Id:VolumeId,Size:Size,AZ:AvailabilityZone}" --output table

Write-Host "`n=== Unused Security Groups (no attachments) ===" -ForegroundColor Yellow
$sgs = aws ec2 describe-security-groups --region $Region --output json | ConvertFrom-Json
foreach ($sg in $sgs.SecurityGroups) {
  if ($sg.GroupName -eq "default") { continue }
  $refs = aws ec2 describe-network-interfaces --region $Region --filters "Name=group-id,Values=$($sg.GroupId)" --query "length(NetworkInterfaces)" --output text
  if ($refs -eq "0") {
    Write-Host "DELETE candidate: $($sg.GroupId) $($sg.GroupName)" -ForegroundColor Red
  }
}

Write-Host "`nTo remove Terraform-managed ALB after disabling enable_legacy_alb:" -ForegroundColor Cyan
Write-Host "  cd planmyjourney-terraform && terraform apply -var-file=environments/prod.tfvars"
