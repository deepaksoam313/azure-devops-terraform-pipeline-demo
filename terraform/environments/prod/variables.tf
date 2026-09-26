# =============================================================================
# FILE: environments/prod/variables.tf
# PURPOSE: Declares all variables for the PROD environment.
#
# DIFFERENCES FROM DEV variables.tf:
# ------------------------------------
# 1. ssh_source_ranges default is EMPTY (no open SSH in prod)
# 2. Additional variables for prod-only features:
#    - kms_key_name         : Customer-managed encryption key (CMEK)
#    - alert_email          : Who gets notified on infrastructure issues
#    - multi_region_subnets : Prod spans multiple regions for HA
# =============================================================================

# -----------------------------------------------------------------------------
# GCP PROJECT SETTINGS
# -----------------------------------------------------------------------------

variable "project_id" {
  description = "The GCP project ID for the prod environment. Should be a SEPARATE project from dev."
  type        = string
  # No default — must be explicitly set in terraform.tfvars
  # Separate project = separate billing, separate IAM, blast radius isolation
}

variable "region" {
  description = "Primary GCP region for prod resources."
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name — always 'prod' for this folder."
  type        = string
  default     = "prod"
}

# -----------------------------------------------------------------------------
# GCS BUCKET SETTINGS
# -----------------------------------------------------------------------------

variable "app_bucket_name" {
  description = "Name of the production application GCS bucket. Must be globally unique."
  type        = string
}

variable "bucket_location" {
  description = "Geographic location for the prod GCS bucket."
  type        = string
  default     = "US"
}

variable "kms_key_name" {
  description = <<EOT
  Cloud KMS key for Customer-Managed Encryption (CMEK) of the GCS bucket.
  Format: projects/{project}/locations/{location}/keyRings/{ring}/cryptoKeys/{key}
  Required in prod for compliance. Leave empty to use Google-managed encryption.
  EOT
  type        = string
  default     = ""
  # Example: "projects/my-prod-project/locations/us/keyRings/prod-keyring/cryptoKeys/gcs-key"
}

# -----------------------------------------------------------------------------
# VPC NETWORK SETTINGS
# Prod has TWO subnets in TWO regions for high availability
# -----------------------------------------------------------------------------

variable "vpc_name" {
  description = "Name of the production VPC network."
  type        = string
  default     = "prod-vpc"
}

variable "primary_subnet_cidr" {
  description = "CIDR for the primary prod subnet (us-central1)."
  type        = string
  default     = "10.10.1.0/24"   # different range from dev (10.0.1.0/24) — no overlap
}

variable "secondary_subnet_cidr" {
  description = "CIDR for the secondary prod subnet (us-east1) for high availability."
  type        = string
  default     = "10.10.2.0/24"
}

# -----------------------------------------------------------------------------
# SECURITY SETTINGS — STRICTER THAN DEV
# -----------------------------------------------------------------------------

variable "ssh_source_ranges" {
  description = <<EOT
  IP ranges allowed to SSH into prod VMs.
  PROD: Locked to corporate VPN / office IP ranges only.
  NEVER use 0.0.0.0/0 in production.
  EOT
  type        = list(string)
  # No default — must be explicitly provided in terraform.tfvars
  # Forces the team to consciously set allowed IPs for prod
}

variable "alert_email" {
  description = "Email address for infrastructure alerts and notifications in prod."
  type        = string
  default     = ""
}
