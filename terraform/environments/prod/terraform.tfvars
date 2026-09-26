# =============================================================================
# FILE: environments/prod/terraform.tfvars
# PURPOSE: Actual VALUES for prod environment variables.
#
# PROD vs DEV KEY DIFFERENCES:
# ┌─────────────────────┬──────────────────────┬───────────────────────────┐
# │ Setting             │ Dev                  │ Prod                      │
# ├─────────────────────┼──────────────────────┼───────────────────────────┤
# │ project_id          │ my-project-dev-xxx   │ my-project-prod-xxx       │
# │ vpc_name            │ dev-vpc              │ prod-vpc                  │
# │ subnet_cidr         │ 10.0.1.0/24          │ 10.10.1.0/24 + 10.10.2.0 │
# │ versioning          │ false                │ true                      │
# │ force_destroy       │ true                 │ false (NEVER true)        │
# │ flow_logs           │ false                │ true                      │
# │ ssh_source_ranges   │ 0.0.0.0/0            │ corporate IPs only        │
# │ storage_class       │ STANDARD             │ STANDARD + lifecycle      │
# │ kms_key             │ none                 │ CMEK key                  │
# └─────────────────────┴──────────────────────┴───────────────────────────┘
#
# IMPORTANT:
# ✅ Commit this file — values are non-sensitive config
# ❌ NEVER put passwords or keys here
# ❌ NEVER set force_destroy = true in prod
# =============================================================================

# -----------------------------------------------------------------------------
# GCP PROJECT — SEPARATE project from dev for full isolation
# REPLACE with your actual prod GCP project ID
# -----------------------------------------------------------------------------
project_id  = "YOUR_GCP_PROD_PROJECT_ID" # e.g. "my-project-prod-789012"
region      = "us-central1"
environment = "prod"

# -----------------------------------------------------------------------------
# GCS BUCKET — prod bucket, versioning enabled, CMEK encryption
# -----------------------------------------------------------------------------
app_bucket_name = "prod-myapp-data-bucket-001" # CHANGE THIS — must be globally unique
bucket_location = "US"

# Customer-Managed Encryption Key (CMEK) — uncomment and set when KMS is ready
# kms_key_name = "projects/YOUR_GCP_PROD_PROJECT_ID/locations/us/keyRings/prod-keyring/cryptoKeys/gcs-key"
kms_key_name = "" # set to empty to use Google-managed encryption for now

# -----------------------------------------------------------------------------
# VPC NETWORK — prod has two subnets in two regions for high availability
# Different CIDR from dev to allow future VPC peering without overlap
# -----------------------------------------------------------------------------
vpc_name              = "prod-vpc"
primary_subnet_cidr   = "10.10.1.0/24" # us-central1 — 254 usable IPs
secondary_subnet_cidr = "10.10.2.0/24" # us-east1    — 254 usable IPs

# -----------------------------------------------------------------------------
# SECURITY — LOCKED DOWN in prod
# Replace with your actual corporate VPN / office IP range
# Example corporate IP ranges:
#   "203.0.113.0/24"   (your office public IP range)
#   "10.0.0.0/8"       (internal corporate network via VPN)
# -----------------------------------------------------------------------------
ssh_source_ranges = ["10.0.0.0/8"] # REPLACE with your corporate IP range

# -----------------------------------------------------------------------------
# ALERTING
# -----------------------------------------------------------------------------
alert_email = "platform-team@yourcompany.com" # REPLACE with your team email
