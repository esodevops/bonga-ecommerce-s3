# Cloud Storage Integration Guide

This guide explains how to configure the pipeline to fetch private CSV data from cloud storage instead of committing sensitive data to Git.

## Overview

The project now supports pulling CSV datasets from:

- **AWS S3** - Simple Storage Service
- **Azure Blob Storage** - Azure object storage
- **Google Cloud Storage (GCS)** - Google's object storage

## Why This Matters

- **Security**: Private data is never committed to Git
- **Compliance**: Easier to meet data governance requirements
- **Scalability**: Handle production-scale datasets without bloating the repo
- **Flexibility**: Switch storage backends without code changes

## Setup Instructions

### Step 1: Create `.env.storage` File

Copy the template and configure for your storage backend:

```bash
cp .env.storage.example .env.storage
# Edit .env.storage with your credentials (see examples below)
```

**⚠️ IMPORTANT**: Add `.env.storage` to `.gitignore` - it's already included, but verify it's not tracked:

```bash
git status .env.storage  # Should show "fatal: pathspec did not match any files"
```

---

## Storage Backend Configuration

### AWS S3

```bash
# .env.storage
STORAGE_TYPE=s3
S3_BUCKET=my-ecommerce-data
S3_PREFIX=production/csvs
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_DEFAULT_REGION=us-east-1
```

**Setup**:

1. Create an S3 bucket (e.g., `my-ecommerce-data`)
2. Upload your CSV files to `s3://my-ecommerce-data/production/csvs/`
3. Create an IAM user with S3 read-only access
4. Store credentials in `.env.storage` (local) or GitHub Secrets (CI/CD)

---

### Azure Blob Storage

```bash
# .env.storage
STORAGE_TYPE=azure
AZURE_STORAGE_ACCOUNT=mystorageaccount
AZURE_STORAGE_KEY=your_account_key
AZURE_CONTAINER=private-data
```

**Setup**:

1. Create an Azure Storage Account
2. Create a container (e.g., `private-data`)
3. Upload your CSV files to the container
4. Get the storage account name and key from Azure Portal
5. Store credentials in `.env.storage` (local) or GitHub Secrets (CI/CD)

---

### Google Cloud Storage (GCS)

```bash
# .env.storage
STORAGE_TYPE=gcs
GCS_BUCKET=my-ecommerce-data
GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
```

**Setup**:

1. Create a GCS bucket (e.g., `my-ecommerce-data`)
2. Create a Service Account with Storage Object Viewer role
3. Download the service account JSON key
4. Upload your CSV files to the bucket
5. Store the JSON key path in `.env.storage` (local)

For CI/CD, encode the JSON as a GitHub Secret:

```bash
# Convert JSON to base64 for secret
cat service-account.json | base64 -w0 | xclip -selection clipboard
# Then decode in workflow
echo ${{ secrets.GCS_SERVICE_ACCOUNT_JSON }} | base64 -d > /tmp/sa.json
export GOOGLE_APPLICATION_CREDENTIALS=/tmp/sa.json
```

---

## Usage

### Local Development

**Option 1: Using Cloud Storage**

```bash
# Copy template and configure
cp .env.storage.example .env.storage
# Edit .env.storage with your credentials

# Run pipeline (auto-fetches from cloud storage)
make pipeline-dev
```

**Option 2: Using Demo Data (No Setup Required)**

```bash
# If .env.storage doesn't exist, pipeline uses data/raw/
make pipeline-dev
```

### GitHub Actions (CI/CD)

Store cloud storage credentials as **GitHub Secrets** in your repository settings:

**For S3**:

- `STORAGE_TYPE` = `s3`
- `S3_BUCKET` = your bucket name
- `S3_PREFIX` = your prefix (e.g., `data`)
- `AWS_ACCESS_KEY_ID` = IAM user access key
- `AWS_SECRET_ACCESS_KEY` = IAM user secret key
- `AWS_DEFAULT_REGION` = region (e.g., `us-east-1`)

**For Azure**:

- `STORAGE_TYPE` = `azure`
- `AZURE_STORAGE_ACCOUNT` = account name
- `AZURE_STORAGE_KEY` = account key

**For GCS**:

- `STORAGE_TYPE` = `gcs`
- `GCS_BUCKET` = bucket name
- `GOOGLE_APPLICATION_CREDENTIALS` = base64-encoded service account JSON

The workflow automatically fetches data before loading into PostgreSQL.

---

## Data Fetching Process

### Automatic Flow

```
1. GitHub push to main branch
   ↓
2. Workflow checkout code
   ↓
3. Fetch CSV files from cloud storage (if STORAGE_TYPE is set)
   ↓
4. Create PostgreSQL schema
   ↓
5. Load CSVs into database
   ↓
6. Run validation checks
   ↓
7. Report status
```

### Manual Flow (Local)

```bash
# Manually fetch data without running the full pipeline
STORAGE_TYPE=s3 S3_BUCKET=my-bucket bash scripts/fetch_data_from_storage.sh

# Then run the pipeline
make pipeline-dev
```

---

## Project Structure

```
├── scripts/
│   ├── run_pipeline.sh                 # Main pipeline (now fetches cloud data)
│   └── fetch_data_from_storage.sh      # Cloud storage fetch logic
├── .env.storage.example                # Template with all storage options
├── .gitignore                          # Excludes .env.storage and data/private/
├── data/
│   ├── raw/                            # Demo data (committed to repo)
│   └── private/                        # Private data (ignored by Git)
└── .github/workflows/
    └── load-data-pipeline.yml          # Updated with cloud storage support
```

---

## Troubleshooting

### "No CSV files found"

**Cause**: Storage credentials are invalid or files don't exist in the configured path.

**Solution**:

```bash
# Verify credentials
export STORAGE_TYPE=s3
export S3_BUCKET=my-bucket
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
bash scripts/fetch_data_from_storage.sh -v

# List files in storage
aws s3 ls s3://my-bucket/data/
```

### "Permission denied" errors

**Cause**: IAM user/service account lacks read permissions.

**Solution**:

- **S3**: Add `s3:GetObject` permission to the bucket
- **Azure**: Assign "Storage Blob Data Reader" role
- **GCS**: Assign "Storage Object Viewer" role

### "Module not found" (AWS CLI, Azure CLI, etc.)

**Cause**: CLI tools not installed in the environment.

**Solution**: The scripts auto-install missing tools, but you can pre-install:

```bash
# AWS
pip install awscli

# Azure
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# GCS
curl https://sdk.cloud.google.com | bash
```

---

## Security Best Practices

1. **Never commit credentials**: Keep `.env.storage` in `.gitignore`
2. **Use IAM roles in CI/CD**: Don't use root credentials
3. **Rotate credentials regularly**: Update secrets every 90 days
4. **Use short-lived tokens**: If your cloud provider supports them
5. **Audit access logs**: Monitor who accesses your data
6. **Encrypt at rest**: Enable encryption in your storage backend
7. **Use VPC endpoints**: For private connectivity (AWS/Azure/GCS)

---

## Migration from Demo Data to Production

### Step 1: Upload Real Data to Cloud Storage

```bash
# Example: Upload to S3
aws s3 cp data/real/products.csv s3://my-ecommerce-data/production/csvs/
aws s3 cp data/real/customers.csv s3://my-ecommerce-data/production/csvs/
# ... repeat for all CSVs
```

### Step 2: Configure `.env.storage`

```bash
STORAGE_TYPE=s3
S3_BUCKET=my-ecommerce-data
S3_PREFIX=production/csvs
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
```

### Step 3: Test Locally

```bash
make pipeline-dev
```

### Step 4: Update GitHub Secrets

Set the same variables in your repository's GitHub Secrets.

### Step 5: Deploy

Push to `main` branch and verify the workflow succeeds.

---

## References

- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [Azure Blob Storage Documentation](https://docs.microsoft.com/en-us/azure/storage/blobs/)
- [Google Cloud Storage Documentation](https://cloud.google.com/storage/docs)
- [GitHub Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
