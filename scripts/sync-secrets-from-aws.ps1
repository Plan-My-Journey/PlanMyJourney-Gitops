#Requires -Version 5.1
# Sync Kubernetes secrets from AWS Secrets Manager into prod and dev namespaces.
# Does not print secret values.
$ErrorActionPreference = "Stop"
$kubectl = Join-Path $env:USERPROFILE ".local\bin\kubectl.exe"
if (-not (Test-Path $kubectl)) { $kubectl = "kubectl" }

$Region = "us-east-1"
$Project = "ai-travel"

function Get-AwsSecretPlain($Name) {
  aws secretsmanager get-secret-value --secret-id $Name --region $Region --query SecretString --output text
}

function Get-AwsSecretJson($Name) {
  Get-AwsSecretPlain $Name | ConvertFrom-Json
}

function Ensure-Namespace($Ns) {
  & $kubectl create namespace $Ns --dry-run=client -o yaml | & $kubectl apply -f -
}

Write-Host "Fetching AWS secrets (values not printed)..." -ForegroundColor Cyan
$jwt = Get-AwsSecretPlain "$Project/jwt-secret/prod"
$rds = Get-AwsSecretJson "$Project/rds/master-password/prod"
$geoapifySecret = Get-AwsSecretJson "$Project/third-party-apis/prod"
$openWeather = "REPLACE_ME"
try {
  $openWeatherSecret = Get-AwsSecretJson "$Project/openweather-api-key/prod"
  if ($openWeatherSecret.OPENWEATHER_API_KEY) {
    $openWeather = $openWeatherSecret.OPENWEATHER_API_KEY
  }
} catch {
  if ($geoapifySecret.OPENWEATHER_API_KEY) {
    $openWeather = $geoapifySecret.OPENWEATHER_API_KEY
  }
}

$rdsHost = (aws rds describe-db-instances --region $Region --query "DBInstances[?DBName=='ai_travel_prod'].Endpoint.Address" --output text)
if (-not $rdsHost) {
  $rdsHost = (aws rds describe-db-instances --region $Region --query "DBInstances[0].Endpoint.Address" --output text)
}

# Alembic reads DATABASE_URL via ConfigParser, which treats % as interpolation syntax.
$encodedPassword = [uri]::EscapeDataString($rds.password) -replace '%', '%%'
$userDbUrl = "postgresql+psycopg://$($rds.username):${encodedPassword}@${rdsHost}:5432/user_db"
$travelDbUrl = "postgresql+psycopg://$($rds.username):${encodedPassword}@${rdsHost}:5432/travel_db"

$geoapify = if ($geoapifySecret.GEOAPIFY_API_KEY) { $geoapifySecret.GEOAPIFY_API_KEY } else { "REPLACE_ME" }

foreach ($ns in @("prod", "dev")) {
  Ensure-Namespace $ns

  & $kubectl create secret generic ai-service-secrets `
    --namespace $ns `
    --from-literal=jwt_secret_key=$jwt `
    --dry-run=client -o yaml | & $kubectl apply -f -

  & $kubectl create secret generic user-service-secrets `
    --namespace $ns `
    --from-literal=jwt_secret_key=$jwt `
    --from-literal=database_url=$userDbUrl `
    --dry-run=client -o yaml | & $kubectl apply -f -

  & $kubectl create secret generic travel-service-secrets `
    --namespace $ns `
    --from-literal=jwt_secret_key=$jwt `
    --from-literal=database_url=$travelDbUrl `
    --dry-run=client -o yaml | & $kubectl apply -f -

  & $kubectl create secret generic utility-service-secrets `
    --namespace $ns `
    --from-literal=jwt_secret_key=$jwt `
    --from-literal=openweather_api_key=$openWeather `
    --from-literal=geoapify_api_key=$geoapify `
    --dry-run=client -o yaml | & $kubectl apply -f -

  Write-Host "Secrets applied in namespace: $ns" -ForegroundColor Green
}

if ($openWeather -eq "REPLACE_ME" -or $geoapify -eq "REPLACE_ME") {
  Write-Host ""
  Write-Host "WARNING: API keys are still placeholders in AWS Secrets Manager." -ForegroundColor Yellow
  Write-Host "Geoapify: ai-travel/third-party-apis/prod" -ForegroundColor Yellow
  Write-Host "OpenWeather: ai-travel/openweather-api-key/prod" -ForegroundColor Yellow
}

Write-Host "Done. Restart deployments if pods were in CreateContainerConfigError." -ForegroundColor Green
