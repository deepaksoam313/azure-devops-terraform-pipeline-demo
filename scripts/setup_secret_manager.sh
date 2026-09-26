#!/bin/bash
# =============================================================================
# SCRIPT: setup_secret_manager.sh
# PURPOSE: One-time setup script to enable Secret Manager API and create
#          the GCS bucket for Terraform state.
#          Run this ONCE manually before running any Terraform commands.
#
# USAGE:
#   chmod +x scripts/setup_secret_manager.sh
#   ./scripts/setup_secret_manager.sh <PROJECT_ID> <TFSTATE_BUCKET_NAME> <ENVIRONMENT>
#
# EXAMPLE:
#   ./scripts/setup_secret_manager.sh my-project-dev-123 my-tfstate-bucket dev
# =============================================================================

set -e   # exit immediately on any error

# ---- Arguments ----
PROJECT_ID=${1:?"ERROR: PROJECT_ID is required. Usage: $0 <PROJECT_ID> <BUCKET_NAME> <ENV>"}
TFSTATE_BUCKET=${2:?"ERROR: TFSTATE_BUCKET is required."}
ENVIRONMENT=${3:?"ERROR: ENVIRONMENT is required (dev or prod)."}

echo "=================================================="
echo " Setting up GCP project: $PROJECT_ID"
echo " Environment           : $ENVIRONMENT"
echo " TF State Bucket       : $TFSTATE_BUCKET"
echo "=================================================="

# ---- Step 1: Set active project ----
echo ""
echo "→ Step 1: Setting active GCP project..."
gcloud config set project "$PROJECT_ID"

# ---- Step 2: Enable required GCP APIs ----
echo ""
echo "→ Step 2: Enabling required GCP APIs..."
gcloud services enable \
  secretmanager.googleapis.com \
  storage.googleapis.com \
  compute.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com \
  --project="$PROJECT_ID"

echo "✅ APIs enabled"

# ---- Step 3: Create GCS bucket for Terraform state ----
echo ""
echo "→ Step 3: Creating Terraform state GCS bucket..."

# Check if bucket already exists
if gsutil ls -b "gs://$TFSTATE_BUCKET" &>/dev/null; then
  echo "ℹ️  Bucket gs://$TFSTATE_BUCKET already exists — skipping creation"
else
  gcloud storage buckets create "gs://$TFSTATE_BUCKET" \
    --location=US \
    --uniform-bucket-level-access \
    --project="$PROJECT_ID"
  echo "✅ Bucket gs://$TFSTATE_BUCKET created"
fi

# Enable versioning on the state bucket (allows state rollback)
echo ""
echo "→ Enabling versioning on state bucket..."
gcloud storage buckets update "gs://$TFSTATE_BUCKET" --versioning
echo "✅ Versioning enabled on state bucket"

# ---- Step 4: Create Service Account for Terraform pipeline ----
echo ""
echo "→ Step 4: Creating Terraform pipeline service account..."

SA_NAME="terraform-pipeline-sa"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Check if SA already exists
if gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" &>/dev/null; then
  echo "ℹ️  Service account $SA_EMAIL already exists — skipping creation"
else
  gcloud iam service-accounts create "$SA_NAME" \
    --display-name="Terraform Pipeline Service Account" \
    --description="Used by Azure DevOps pipeline to run Terraform" \
    --project="$PROJECT_ID"
  echo "✅ Service account $SA_EMAIL created"
fi

# ---- Step 5: Grant required IAM roles to the service account ----
echo ""
echo "→ Step 5: Granting IAM roles to service account..."

ROLES=(
  "roles/editor"                          # create/modify most resources
  "roles/secretmanager.admin"             # manage secrets
  "roles/storage.admin"                   # manage GCS buckets (including state)
  "roles/iam.serviceAccountTokenCreator"  # impersonate service accounts
)

for ROLE in "${ROLES[@]}"; do
  echo "  Granting $ROLE..."
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="$ROLE" \
    --quiet
done
echo "✅ IAM roles granted"

# ---- Step 6: Create and download service account key ----
echo ""
echo "→ Step 6: Creating service account key for Azure DevOps..."

KEY_FILE="./terraform-sa-key-${ENVIRONMENT}.json"

gcloud iam service-accounts keys create "$KEY_FILE" \
  --iam-account="$SA_EMAIL" \
  --project="$PROJECT_ID"

echo "✅ Service account key saved to: $KEY_FILE"
echo ""
echo "⚠️  IMPORTANT NEXT STEPS:"
echo "   1. Copy the contents of $KEY_FILE"
echo "   2. In Azure DevOps → Pipelines → Library → Variable Groups"
echo "   3. Create a variable group named: 'gcp-credentials-${ENVIRONMENT}'"
echo "   4. Add variable: GCP_SA_KEY = <paste key file contents> → mark as SECRET"
echo "   5. Add variable: GCP_PROJECT_ID = $PROJECT_ID"
echo "   6. DELETE $KEY_FILE from your local machine after uploading to ADO"
echo ""
echo "=================================================="
echo " ✅ Setup complete for $ENVIRONMENT environment!"
echo "=================================================="
