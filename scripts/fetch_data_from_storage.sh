#!/usr/bin/env bash
##
## fetch_data_from_storage.sh
## Fetch private CSV datasets from cloud storage (S3, Azure Blob, GCS, or internal bucket)
## Usage:
##   ./scripts/fetch_data_from_storage.sh              # Uses .env.storage for defaults
##   STORAGE_TYPE=s3 ./scripts/fetch_data_from_storage.sh
##

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STORAGE_TYPE="${STORAGE_TYPE:-s3}"
DATA_DIR="${DATA_DIR:-$ROOT_DIR/data/private}"

# Load storage configuration
STORAGE_CONFIG="${STORAGE_CONFIG:-$ROOT_DIR/.env.storage}"
if [[ -f "$STORAGE_CONFIG" ]]; then
  set -a
  source "$STORAGE_CONFIG"
  set +a
fi

# Ensure data directory exists
mkdir -p "$DATA_DIR"

# ============================================================================
# AWS S3
# ============================================================================
fetch_from_s3() {
  local bucket="$1"
  local prefix="${2:-.}"
  local normalized_prefix="${prefix%/}"
  local downloaded_count=0
  local required_files=("products.csv" "customers.csv" "orders.csv" "orderitems.csv")
  
  if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]] || [[ -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
    echo "[ERROR] AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be set for S3 access"
    return 1
  fi
  
  echo "[INFO] Fetching CSV files from S3: s3://$bucket/$prefix"
  
  # Install AWS CLI if not present
  if ! command -v aws &> /dev/null; then
    echo "[STEP] Installing AWS CLI..."
    pip install awscli --quiet || apt-get install -y awscli
  fi
  
  # Set AWS credentials
  export AWS_ACCESS_KEY_ID
  export AWS_SECRET_ACCESS_KEY
  export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
  
  # Preferred path: sync CSV files. This requires s3:ListBucket on the bucket.
  if aws s3 sync "s3://$bucket/$normalized_prefix" "$DATA_DIR/" \
    --include "*.csv" \
    --exclude "*" \
    --no-progress; then
    echo "[DONE] S3 data fetch completed via sync"
    return 0
  fi

  # Fallback path: direct object downloads (works with s3:GetObject only).
  echo "[WARN] S3 sync failed (likely missing s3:ListBucket). Trying direct object downloads..."
  for file in "${required_files[@]}"; do
    if aws s3 cp "s3://$bucket/$normalized_prefix/$file" "$DATA_DIR/$file" --no-progress; then
      downloaded_count=$((downloaded_count + 1))
    else
      echo "[WARN] Could not download s3://$bucket/$normalized_prefix/$file"
    fi
  done

  if [[ $downloaded_count -eq 0 ]]; then
    echo "[ERROR] No CSV files downloaded from S3. Check bucket path and IAM permissions."
    return 1
  fi

  echo "[DONE] S3 data fetch completed via direct object downloads ($downloaded_count files)"
}

# ============================================================================
# Azure Blob Storage
# ============================================================================
fetch_from_azure_blob() {
  local container="$1"
  
  if [[ -z "${AZURE_STORAGE_ACCOUNT:-}" ]] || [[ -z "${AZURE_STORAGE_KEY:-}" ]]; then
    echo "[ERROR] AZURE_STORAGE_ACCOUNT and AZURE_STORAGE_KEY must be set for Blob access"
    return 1
  fi
  
  echo "[INFO] Fetching CSV files from Azure Blob: $container"
  
  # Install Azure CLI if not present
  if ! command -v az &> /dev/null; then
    echo "[STEP] Installing Azure CLI..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | bash
  fi
  
  # Set Azure credentials
  export AZURE_STORAGE_ACCOUNT
  export AZURE_STORAGE_KEY
  
  # Download blobs
  local connection_string="DefaultEndpointsProtocol=https;AccountName=$AZURE_STORAGE_ACCOUNT;AccountKey=$AZURE_STORAGE_KEY;EndpointSuffix=core.windows.net"
  
  # List and download each CSV
  az storage blob list --container-name "$container" \
    --connection-string "$connection_string" \
    --query "[?ends_with(name, '.csv')].name" -o tsv | while read -r blob; do
    echo "[STEP] Downloading: $blob"
    az storage blob download --container-name "$container" \
      --name "$blob" --file "$DATA_DIR/$blob" \
      --connection-string "$connection_string" \
      --no-progress > /dev/null
  done
  
  echo "[DONE] Azure Blob Storage data fetch completed"
}

# ============================================================================
# Google Cloud Storage (GCS)
# ============================================================================
fetch_from_gcs() {
  local bucket="$1"
  
  if [[ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]]; then
    echo "[ERROR] GOOGLE_APPLICATION_CREDENTIALS must point to a valid service account JSON"
    return 1
  fi
  
  echo "[INFO] Fetching CSV files from GCS: gs://$bucket"
  
  # Install GCloud CLI if not present
  if ! command -v gsutil &> /dev/null; then
    echo "[STEP] Installing Google Cloud SDK..."
    curl https://sdk.cloud.google.com | bash
    exec -l $SHELL
  fi
  
  # Authenticate
  gcloud auth activate-service-account --key-file="$GOOGLE_APPLICATION_CREDENTIALS"
  
  # Download all CSV files
  gsutil -m cp "gs://$bucket/*.csv" "$DATA_DIR/" || true
  
  echo "[DONE] GCS data fetch completed"
}

# ============================================================================
# Main Logic
# ============================================================================
case "$STORAGE_TYPE" in
  s3)
    bucket="${S3_BUCKET:-}"
    prefix="${S3_PREFIX:-data}"
    if [[ -z "$bucket" ]]; then
      echo "[ERROR] S3_BUCKET environment variable not set"
      exit 1
    fi
    fetch_from_s3 "$bucket" "$prefix"
    ;;
  azure)
    container="${AZURE_CONTAINER:-private-data}"
    fetch_from_azure_blob "$container"
    ;;
  gcs)
    bucket="${GCS_BUCKET:-}"
    if [[ -z "$bucket" ]]; then
      echo "[ERROR] GCS_BUCKET environment variable not set"
      exit 1
    fi
    fetch_from_gcs "$bucket"
    ;;
  *)
    echo "[ERROR] Unknown STORAGE_TYPE: $STORAGE_TYPE"
    echo "[INFO] Valid options: s3, azure, gcs"
    exit 1
    ;;
esac

echo "[INFO] Data successfully fetched to: $DATA_DIR"
ls -lh "$DATA_DIR"/*.csv 2>/dev/null || echo "[WARN] No CSV files found in $DATA_DIR"
