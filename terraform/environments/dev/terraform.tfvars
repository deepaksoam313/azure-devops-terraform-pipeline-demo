# =============================================================================
# FILE: environments/dev/terraform.tfvars
# PURPOSE: Provides the ACTUAL VALUES for variables declared in variables.tf.
#          This is the only file that differs meaningfully between dev and prod.
#
# IMPORTANT RULES:
# ----------------
# ✅ Commit this file to git — it has non-sensitive config values
# ❌ NEVER put passwords, private keys, or tokens in this file
# ❌ Sensitive values go in Azure DevOps pipeline variable groups (secret)
#    OR are fetched from GCP Secret Manager at runtime
#
# HOW TERRAFORM USES THIS FILE:
# When you run: terraform plan  (or the pipeline runs it)
# Terraform automatically reads terraform.tfvars in the same directory
# and fills in all the variable values defined here.
# =============================================================================

# -----------------------------------------------------------------------------
# GCP PROJECT SETTINGS
# REPLACE these values with your actual GCP project details
# -----------------------------------------------------------------------------
project_id  = "YOUR_GCP_PROJECT_ID"      # e.g. "my-project-dev-123456"
region      = "us-central1"
environment = "dev"

# -----------------------------------------------------------------------------
# GCS BUCKET
# Must be globally unique — add your project name or random suffix
# Naming convention: <env>-<project>-<purpose>-<random>
# -----------------------------------------------------------------------------
app_bucket_name = "dev-myapp-data-bucket-001"   # CHANGE THIS — must be unique
bucket_location = "US"

# -----------------------------------------------------------------------------
# VPC NETWORK
# 10.0.0.0/8 is reserved for private use — safe for internal subnets
# Dev uses 10.0.1.0/24 — gives 254 usable IP addresses
# -----------------------------------------------------------------------------
vpc_name    = "dev-vpc"
subnet_cidr = "10.0.1.0/24"

# -----------------------------------------------------------------------------
# SECURITY
# Dev: SSH open to all IPs for easy access during development
# This is intentionally relaxed — prod will lock this down
# -----------------------------------------------------------------------------
ssh_source_ranges = ["0.0.0.0/0"]
