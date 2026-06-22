#Requires -Version 5.1
# Update Route53 API records to the Envoy Gateway NLB.
# Frontend apex/www stay on CloudFront — only api.* records are changed here.
param(
  [string]$Domain = "invest-iq.online",
  [string]$Region = "us-east-1"
)

$ErrorActionPreference = "Stop"
$kubectl = Join-Path $env:USERPROFILE ".local\bin\kubectl.exe"
if (-not (Test-Path $kubectl)) { $kubectl = "kubectl" }

Write-Host "Reading Gateway NLB hostname..." -ForegroundColor Cyan
$nlbDns = & $kubectl get gateway api-gateway -n gateway-system -o jsonpath='{.status.addresses[0].value}' 2>$null
if (-not $nlbDns) {
  throw "Gateway address not ready. Check: kubectl get gateway api-gateway -n gateway-system"
}

Write-Host "NLB hostname: $nlbDns" -ForegroundColor Green
$nlbZoneId = aws elbv2 describe-load-balancers --region $Region --query "LoadBalancers[?DNSName=='$nlbDns'].CanonicalHostedZoneId | [0]" --output text
if (-not $nlbZoneId -or $nlbZoneId -eq "None") {
  throw "Could not resolve NLB hosted zone ID for $nlbDns"
}

$zoneId = aws route53 list-hosted-zones-by-name --dns-name $Domain --query "HostedZones[?Name=='$Domain.'].Id | [0]" --output text
if (-not $zoneId -or $zoneId -eq "None") {
  throw "Route53 hosted zone not found for $Domain"
}
$zoneId = $zoneId -replace "/hostedzone/", ""

# API traffic only — do NOT repoint apex/www (those use CloudFront).
$records = @(
  @{ Name = "api.$Domain"; Comment = "prod API via Envoy NLB" },
  @{ Name = "dev-api.$Domain"; Comment = "dev API via Envoy NLB" }
)

foreach ($record in $records) {
  $changeBatch = @{
    Changes = @(
      @{
        Action = "UPSERT"
        ResourceRecordSet = @{
          Name = $record.Name
          Type = "A"
          AliasTarget = @{
            HostedZoneId = $nlbZoneId
            DNSName = "$nlbDns."
            EvaluateTargetHealth = $true
          }
        }
      }
    )
  } | ConvertTo-Json -Depth 6 -Compress

  aws route53 change-resource-record-sets --hosted-zone-id $zoneId --change-batch $changeBatch | Out-Null
  Write-Host "UPSERT A alias: $($record.Name) -> $nlbDns ($($record.Comment))" -ForegroundColor Green
}

Write-Host "Done. Verify: nslookup api.$Domain" -ForegroundColor Cyan
