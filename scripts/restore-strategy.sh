#!/usr/bin/env bash
set -euo pipefail

BACKUP_DATE="${1:-}"
ENVIRONMENT="${2:-prod}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
BACKUP_BUCKET="${BACKUP_BUCKET:-ai-travel-prod-logs-${ACCOUNT_ID}-${AWS_REGION}}"
S3_PREFIX="backups/${BACKUP_DATE}"

if [[ -z "${BACKUP_DATE}" ]]; then
  echo "Usage: $0 BACKUP_DATE [ENVIRONMENT]"
  exit 1
fi

echo "WARNING: Starting disaster recovery restore for ${BACKUP_DATE}"

echo "Restoring frontend S3..."
FRONTEND_BUCKET="$(aws s3api list-buckets --query "Buckets[?contains(Name, 'frontend')].Name | [0]" --output text)"
if [[ -n "${FRONTEND_BUCKET}" && "${FRONTEND_BUCKET}" != "None" ]]; then
  aws s3 sync "s3://${BACKUP_BUCKET}/${S3_PREFIX}/s3-frontend/" "s3://${FRONTEND_BUCKET}/" --delete --region "${AWS_REGION}"
fi

echo "Restoring RDS from snapshot..."
SNAPSHOT_ID="manual-backup-${BACKUP_DATE}"
RESTORED_DB="${DB_ID:-ai-travel-postgres-${ENVIRONMENT}}-restored"
if aws rds describe-db-snapshots --db-snapshot-identifier "${SNAPSHOT_ID}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  aws rds restore-db-instance-from-db-snapshot \
    --db-instance-identifier "${RESTORED_DB}" \
    --db-snapshot-identifier "${SNAPSHOT_ID}" \
    --region "${AWS_REGION}"
else
  echo "  Snapshot ${SNAPSHOT_ID} not found"
fi

echo "Restoring DynamoDB (creates new table; verify before cutover)..."
JOBS_TABLE="ai-travel-${ENVIRONMENT}-ai-jobs"
RESTORED_TABLE="${JOBS_TABLE}-restored"
BACKUP_ARN="$(aws dynamodb list-backups --table-name "${JOBS_TABLE}" --region "${AWS_REGION}" \
  --query "BackupSummaries[0].BackupArn" --output text 2>/dev/null || echo "")"
if [[ -n "${BACKUP_ARN}" && "${BACKUP_ARN}" != "None" ]]; then
  aws dynamodb restore-table-from-backup \
    --target-table-name "${RESTORED_TABLE}" \
    --backup-arn "${BACKUP_ARN}" \
    --region "${AWS_REGION}"
else
  echo "  No DynamoDB backup ARN found; use PITR restore in AWS Console if needed"
fi

echo "Restore initiated. Verify restored resources before switching traffic."
