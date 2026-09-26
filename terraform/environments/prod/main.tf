# =============================================================================
# FILE: environments/prod/main.tf
# PURPOSE: Root configuration for the PRODUCTION environment.
#          Same modules as dev — but with STRICTER, PRODUCTION-GRADE settings.
#
# PROD DIFFERENCES FROM DEV:
# ---------------------------
# 1. versioning_enabled  = true   (object history kept — disaster recovery)
# 2. force_destroy       = false  (prevents accidental data loss)
# 3. lifecycle_age_days  = 90     (longer retention before moving to NEARLINE)
# 4. enable_flow_logs    = true   (network traffic captured for security audit)
# 5. ssh_source_ranges   = corporate IPs only (no open internet SSH)
# 6. Two subnets         = us-central1 + us-east1 (high availability)
# 7. routing_mode        = GLOBAL (routes shared across regions)
# 8. kms_key_name        = CMEK encryption (if provided)
#
# RESOURCES CREATED IN GCP (prod environment):
#   1. GCS Bucket          — versioned, encrypted application storage
#   2. VPC Network         — prod-grade isolated network
#   3. Subnet (us-central1) — primary region subnet
#   4. Subnet (us-east1)   — secondary region for HA
#   5. Cloud Router        — for VPN / NAT
#   6. Cloud NAT           — private VM internet access
#   7. Firewall Rules      — locked-down SSH, internal-only, deny-all
# =============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

# -----------------------------------------------------------------------------
# PROVIDER
# Same as dev — credentials come from GOOGLE_CREDENTIALS env var
# set by Azure DevOps pipeline using the prod service account secret
# -----------------------------------------------------------------------------
provider "google" {
  project = var.project_id
  region  = var.region
}

# -----------------------------------------------------------------------------
# LOCALS
# Common labels for all prod resources
# -----------------------------------------------------------------------------
locals {
  common_labels = {
    environment = var.environment # "prod"
    managed_by  = "terraform"
    project     = var.project_id
    team        = "platform-engineering"
    criticality = "high" # prod-specific label for cost/ops tracking
  }
}

# =============================================================================
# MODULE CALL 1: GCS Bucket (PROD settings)
# KEY DIFFERENCES FROM DEV:
#   - versioning_enabled = true   → keeps deleted/overwritten object history
#   - force_destroy      = false  → terraform destroy will FAIL if bucket has objects
#   - lifecycle_age_days = 90     → objects stay in STANDARD for 90 days (not 30)
#   - kms_key_name               → CMEK encryption if key is provided
# =============================================================================
module "app_bucket" {
  source = "../../modules/gcs_bucket"

  # ---- Required ----
  bucket_name = var.app_bucket_name
  project_id  = var.project_id
  environment = var.environment # "prod"

  # ---- Prod-specific settings ----
  location           = var.bucket_location
  storage_class      = "STANDARD"
  versioning_enabled = true             # ✅ ENABLED in prod — disaster recovery
  force_destroy      = false            # ❌ NEVER true in prod — prevents accidental deletion
  lifecycle_age_days = 90               # longer retention in prod
  kms_key_name       = var.kms_key_name # CMEK encryption (empty = Google-managed)

  additional_labels = local.common_labels

  # ---- IAM — prod service accounts ----
  iam_bindings = {
    "roles/storage.objectViewer" = [
      "serviceAccount:prod-reader@${var.project_id}.iam.gserviceaccount.com"
    ]
    "roles/storage.objectAdmin" = [
      "serviceAccount:prod-pipeline@${var.project_id}.iam.gserviceaccount.com"
    ]
  }
}

# =============================================================================
# MODULE CALL 2: VPC Network (PROD settings)
# KEY DIFFERENCES FROM DEV:
#   - Two subnets across two regions (us-central1 + us-east1) for HA
#   - enable_flow_logs  = true   → captures traffic for security/compliance
#   - routing_mode      = GLOBAL → routes shared across all regions
#   - ssh_source_ranges = corporate IPs only (NOT 0.0.0.0/0)
# =============================================================================
module "vpc" {
  source = "../../modules/vpc_network"

  vpc_name       = var.vpc_name
  project_id     = var.project_id
  environment    = var.environment # "prod"
  primary_region = var.region      # "us-central1"

  # ---- Two subnets for High Availability ----
  subnets = [
    {
      # Primary subnet — us-central1
      name       = "prod-subnet-uc1"
      region     = "us-central1"
      cidr_range = var.primary_subnet_cidr # "10.10.1.0/24"
      secondary_ranges = [
        {
          range_name = "prod-pods-uc1"
          cidr_range = "10.11.0.0/16" # GKE pod IPs — us-central1
        },
        {
          range_name = "prod-services-uc1"
          cidr_range = "10.12.0.0/20" # GKE service IPs — us-central1
        }
      ]
    },
    {
      # Secondary subnet — us-east1 (different region = HA)
      name       = "prod-subnet-ue1"
      region     = "us-east1"
      cidr_range = var.secondary_subnet_cidr # "10.10.2.0/24"
      secondary_ranges = [
        {
          range_name = "prod-pods-ue1"
          cidr_range = "10.13.0.0/16" # GKE pod IPs — us-east1
        },
        {
          range_name = "prod-services-ue1"
          cidr_range = "10.14.0.0/20" # GKE service IPs — us-east1
        }
      ]
    }
  ]

  # ---- Prod-specific network settings ----
  routing_mode      = "GLOBAL"              # global routing for multi-region prod
  enable_flow_logs  = true                  # ✅ ENABLED in prod — security/compliance audit
  ssh_source_ranges = var.ssh_source_ranges # corporate IPs only — NOT 0.0.0.0/0
}

# =============================================================================
# MODULE CALL 3: Secret Manager (PROD)
# PROD DIFFERENCES FROM DEV:
#   - Secret names prefixed with "prod-" (isolated from dev secrets)
#   - Stricter accessors — only prod service accounts
#   - No default placeholder values — pipeline MUST supply real values
# =============================================================================
variable "db_password" {
  description = "Production database password — injected by pipeline as TF_VAR_db_password"
  type        = string
  sensitive   = true
  # No default in prod — pipeline MUST provide this. Fail fast if missing.
}

variable "api_key" {
  description = "Production external API key — injected by pipeline as TF_VAR_api_key"
  type        = string
  sensitive   = true
  # No default in prod — pipeline MUST provide this.
}

module "secrets" {
  source      = "../../modules/secret_manager"
  project_id  = var.project_id
  environment = var.environment # "prod"

  secrets = {
    "prod-db-password" = {
      value = var.db_password
      type  = "database"
      accessors = [
        "serviceAccount:prod-pipeline@${var.project_id}.iam.gserviceaccount.com"
      ]
    }

    "prod-api-key" = {
      value = var.api_key
      type  = "api-key"
      accessors = [
        "serviceAccount:prod-pipeline@${var.project_id}.iam.gserviceaccount.com"
      ]
    }
  }
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "app_bucket_url" {
  description = "URL of the prod GCS bucket"
  value       = module.app_bucket.bucket_url
}

output "app_bucket_name" {
  description = "Name of the prod GCS bucket"
  value       = module.app_bucket.bucket_name
}

output "vpc_name" {
  description = "Name of the prod VPC network"
  value       = module.vpc.vpc_name
}

output "vpc_id" {
  description = "ID of the prod VPC"
  value       = module.vpc.vpc_id
}

output "subnet_cidr_ranges" {
  description = "Map of prod subnet name to CIDR range (both regions)"
  value       = module.vpc.subnet_cidr_ranges
}

output "subnet_self_links" {
  description = "Map of prod subnet name to self_link — used for GKE cluster config"
  value       = module.vpc.subnet_self_links
}

output "secret_names" {
  description = "Map of secret name to secret_id in GCP Secret Manager"
  value       = module.secrets.secret_names
}
