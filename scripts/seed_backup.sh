#!/usr/bin/env bash
# Upload sample backup files to the storage container to demonstrate the system.
# Usage: ./scripts/seed_backup.sh <storage_account_name>

set -euo pipefail

STORAGE_ACCOUNT="${1:?Usage: $0 <storage_account_name>}"
CONTAINER="backups"
DATE=$(date -u +%Y-%m-%d)

echo "Seeding backup container in ${STORAGE_ACCOUNT}..."

# Database backup snapshot
az storage blob upload \
  --account-name "$STORAGE_ACCOUNT" \
  --container-name "$CONTAINER" \
  --name "db/${DATE}/snapshot.json" \
  --data '{"type":"db_snapshot","timestamp":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","records":4821,"size_mb":12}' \
  --auth-mode login

# Application config backup
az storage blob upload \
  --account-name "$STORAGE_ACCOUNT" \
  --container-name "$CONTAINER" \
  --name "config/${DATE}/app-config.json" \
  --data '{"type":"app_config","timestamp":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","version":"1.4.2","env":"prod"}' \
  --auth-mode login

# Simulate an update to trigger versioning
az storage blob upload \
  --account-name "$STORAGE_ACCOUNT" \
  --container-name "$CONTAINER" \
  --name "db/${DATE}/snapshot.json" \
  --data '{"type":"db_snapshot","timestamp":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","records":4830,"size_mb":12,"note":"incremental update"}' \
  --auth-mode login \
  --overwrite

echo ""
echo "Done. Blobs uploaded to ${STORAGE_ACCOUNT}/${CONTAINER}:"
az storage blob list \
  --account-name "$STORAGE_ACCOUNT" \
  --container-name "$CONTAINER" \
  --auth-mode login \
  --query "[].{name:name, size:properties.contentLength}" \
  --output table

echo ""
echo "Versions for db/${DATE}/snapshot.json:"
az storage blob list \
  --account-name "$STORAGE_ACCOUNT" \
  --container-name "$CONTAINER" \
  --include v \
  --auth-mode login \
  --prefix "db/${DATE}/snapshot.json" \
  --query "[].{name:name, versionId:versionId, isCurrent:isCurrentVersion}" \
  --output table
