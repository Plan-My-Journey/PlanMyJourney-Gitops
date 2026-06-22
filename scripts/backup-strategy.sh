#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-prod}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
BACKUP_DATE="$(date +%Y%m%d_%H%M%S)"
BACKUP_BUCKET="${BACKUP_BUCKET:-ai-travel-prod-logs-${ACCOUNT_ID}-${AWS_REGION}}"
S3_PREFIX="backups/${BACKUP_DATE}"

echo "Starting backup for ${ENVIRONMENT} (${BACKUP_DATE})..."

echo "Backing up frontend S3 bucket..."
FRONTEND_BUCKET="$(aws s3api list-buckets --query "Buckets[?contains(Name, 'frontend')].Name | [0]" --output text)"
if [[ -n "${FRONTEND_BUCKET}" && "${FRONTEND_BUCKET}" != "None" ]]; then
  aws s3 sync "s3://${FRONTEND_BUCKET}" "s3://${BACKUP_BUCKET}/${S3_PREFIX}/s3-frontend/" --region "${AWS_REGION}"
fi

echo "Exporting DynamoDB job table (if exists)..."
JOBS_TABLE="ai-travel-${ENVIRONMENT}-ai-jobs"
TABLE_ARN="arn:aws:dynamodb:${AWS_REGION}:${ACCOUNT_ID}:table/${JOBS_TABLE}"
if aws dynamodb describe-table --table-name "${JOBS_TABLE}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  aws dynamodb export-table-to-point-in-time \
    --table-arn "${TABLE_ARN}" \
    --s3-bucket "${BACKUP_BUCKET}" \
    --s3-prefix "${S3_PREFIX}/dynamodb" \
    --region "${AWS_REGION}"
else
  echo "  Skipped: ${JOBS_TABLE} not found (run terraform apply for SQS module first)"
fi

echo "Creating RDS snapshot..."
DB_ID="ai-travel-postgres-${ENVIRONMENT}"
if aws rds describe-db-instances --db-instance-identifier "${DB_ID}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  aws rds create-db-snapshot \
    --db-instance-identifier "${DB_ID}" \
    --db-snapshot-identifier "manual-backup-${BACKUP_DATE}" \
    --region "${AWS_REGION}"
else
  echo "  Skipped: ${DB_ID} not found"
fi

echo "Kubernetes resource export..."
mkdir -p "/tmp/k8s-backup-${BACKUP_DATE}"
kubectl get all,configmap,secret,pdb,httproute,gateway -A -o yaml > "/tmp/k8s-backup-${BACKUP_DATE}/cluster-resources.yaml" || true
aws s3 cp "/tmp/k8s-backup-${BACKUP_DATE}/cluster-resources.yaml" \
  "s3://${BACKUP_BUCKET}/${S3_PREFIX}/kubernetes/cluster-resources.yaml" --region "${AWS_REGION}"

echo "Backup completed. Artifacts: s3://${BACKUP_BUCKET}/${S3_PREFIX}/"
