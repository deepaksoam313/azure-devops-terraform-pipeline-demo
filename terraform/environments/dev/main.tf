# =============================================================================
# FILE: environments/dev/main.tf
# PURPOSE: The root configuration for the DEV environment.
#          This file CALLS the reusable modules and passes real values to them.
#          Think of this as the "orchestrator" that wires everything together.
#
# RESOURCES CREATED IN GCP (dev environment):
#   1. GCS Bucket         — application data storage
#   2. VPC Network        — isolated network for dev
#   3. Subnet             — IP range for dev VMs/services
#   4. Cloud Router       — required for Cloud NAT
#   5. Cloud NAT          — outbound internet for private VMs
#   6. Firewall Rules     — allow-internal, allow-ssh, deny-all
#
# MODULES USED:
#   ../../modules/gcs_bucket   — reusable GCS bucket blueprint
#   ../../modules/vpc_network  — reusable VPC + subnet blueprint
# =============================================================================

# -----------------------------------------------------------------------------
# TERRAFORM SETTINGS
# Specifies required Terraform version and providers.
# The google provider authenticates to GCP using the service account key
# injected by Azure DevOps pipeline as env var GOOGLE_CREDENTIALS.
# -----------------------------------------------------------------------------
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
# PROVIDER CONFIGURATION
# Tells Terraform which GCP project and region to use by default.
# Credentials are NOT hardcoded here — they come from the environment variable
# GOOGLE_CREDENTIALS set by the Azure DevOps pipeline using a secret.
# -----------------------------------------------------------------------------
provider "google" {
  project = var.project_id
  region  = var.region
  # credentials = "..." ← DO NOT set here. Use GOOGLE_CREDENTIALS env var instead.
}

# -----------------------------------------------------------------------------
# LOCAL VALUES
# Computed or derived values used multiple times in this file.
# Defined once here to avoid repetition (DRY principle).
# -----------------------------------------------------------------------------
locals {
  # Common labels applied to all resources in this environment
  common_labels = {
    environment = var.environment       # "dev"
    managed_by  = "terraform"
    project     = var.project_id
    team        = "platform-engineering"
  }
}

# =============================================================================
# MODULE CALL 1: GCS Bucket
# Calls the reusable gcs_bucket module and passes dev-specific values.
# The module creates the bucket in GCP with all settings configured.
# =============================================================================
module "app_bucket" {
  # Path to the module — relative from this file's location
  source = "../../modules/gcs_bucket"

  # ---- Required variables (must be provided) ----
  bucket_name = var.app_bucket_name   # from terraform.tfvars
  project_id  = var.project_id        # from terraform.tfvars
  environment = var.environment       # "dev"

  # ---- Optional variables (overriding module defaults for dev) ----
  location           = var.bucket_location  # "US"
  storage_class      = "STANDARD"           # frequently accessed in dev
  versioning_enabled = false                # disabled in dev to save cost
  force_destroy      = true                 # OK to force destroy in dev
  lifecycle_age_days = 30                   # transition to NEARLINE after 30 days

  # Additional labels merged with module's default labels
  additional_labels = local.common_labels

  # ---- IAM: Who can access this bucket ----
  # Format: { "role" = ["member1", "member2"] }
  # NOTE: Replace with actual service account emails for your project
  iam_bindings = {
    "roles/storage.objectViewer" = [
      "serviceAccount:dev-reader@${var.project_id}.iam.gserviceaccount.com"
    ]
    "roles/storage.objectAdmin" = [
      "serviceAccount:dev-pipeline@${var.project_id}.iam.gserviceaccount.com"
    ]
  }
}

# =============================================================================
# MODULE CALL 2: VPC Network
# Calls the reusable vpc_network module and passes dev-specific values.
# Creates the complete network stack: VPC, subnet, router, NAT, firewall rules.
# =============================================================================
module "vpc" {
  source = "../../modules/vpc_network"

  # ---- Required variables ----
  vpc_name       = var.vpc_name       # "dev-vpc"
  project_id     = var.project_id
  environment    = var.environment    # "dev"
  primary_region = var.region         # "us-central1"

  # ---- Subnet configuration ----
  # Creates ONE subnet in dev. Prod might have multiple subnets per region.
  subnets = [
    {
      name       = "dev-subnet-uc1"
      region     = var.region           # "us-central1"
      cidr_range = var.subnet_cidr      # "10.0.1.0/24"

      # Secondary ranges for GKE (if you later add a GKE cluster)
      secondary_ranges = [
        {
          range_name = "dev-pods"
          cidr_range = "10.1.0.0/16"    # Pod IPs — 65536 addresses
        },
        {
          range_name = "dev-services"
          cidr_range = "10.2.0.0/20"    # Service IPs — 4096 addresses
        }
      ]
    }
  ]

  # ---- Optional settings ----
  routing_mode      = "REGIONAL"       # regional routing for dev
  enable_flow_logs  = false            # disabled in dev (saves cost)
  ssh_source_ranges = var.ssh_source_ranges  # open in dev, restricted in prod
}

# =============================================================================
# MODULE CALL 3: Secret Manager
# Creates secrets in GCP Secret Manager for the dev environment.
#
# HOW SECRET VALUES ARE PASSED SAFELY:
# -------------------------------------
# We do NOT hardcode secret values in this file or in terraform.tfvars.
# Instead, the Azure DevOps pipeline passes them as environment variables:
#
#   TF_VAR_db_password = $(DB_PASSWORD)   ← from ADO secret variable group
#
# Terraform automatically picks up TF_VAR_* environment variables.
# The pipeline never prints them — they are masked in logs.
#
# The secrets{} map below uses variable references so nothing is hardcoded.
# =============================================================================
variable "db_password" {
  description = "Database password for dev — injected by pipeline as TF_VAR_db_password"
  type        = string
  sensitive   = true
  default     = "change-me-via-pipeline"   # placeholder — always override in pipeline
}

variable "api_key" {
  description = "External API key for dev — injected by pipeline as TF_VAR_api_key"
  type        = string
  sensitive   = true
  default     = "change-me-via-pipeline"
}

module "secrets" {
  source      = "../../modules/secret_manager"
  project_id  = var.project_id
  environment = var.environment

  secrets = {
    # Database password — used by app service account to connect to Cloud SQL
    "dev-db-password" = {
      value     = var.db_password    # injected from pipeline secret variable
      type      = "database"
      accessors = [
        "serviceAccount:dev-pipeline@${var.project_id}.iam.gserviceaccount.com"
      ]
    }

    # External API key — used by app to call third-party services
    "dev-api-key" = {
      value     = var.api_key        # injected from pipeline secret variable
      type      = "api-key"
      accessors = [
        "serviceAccount:dev-pipeline@${var.project_id}.iam.gserviceaccount.com"
      ]
    }
  }
}

# =============================================================================
# OUTPUTS
# Values printed after terraform apply. Useful for debugging and
# for referencing in other Terraform configurations via remote state.
# =============================================================================

output "app_bucket_url" {
  description = "URL of the created GCS bucket — use this to upload/download objects"
  value       = module.app_bucket.bucket_url
}

output "app_bucket_name" {
  description = "Name of the created GCS bucket"
  value       = module.app_bucket.bucket_name
}

output "vpc_name" {
  description = "Name of the created VPC network"
  value       = module.vpc.vpc_name
}

output "vpc_id" {
  description = "ID of the created VPC — use this when creating GKE clusters or Cloud SQL"
  value       = module.vpc.vpc_id
}

output "subnet_cidr_ranges" {
  description = "Map of subnet name to CIDR range"
  value       = module.vpc.subnet_cidr_ranges
}

output "secret_names" {
  description = "Map of secret name to secret_id in GCP Secret Manager"
  value       = module.secrets.secret_names
}
