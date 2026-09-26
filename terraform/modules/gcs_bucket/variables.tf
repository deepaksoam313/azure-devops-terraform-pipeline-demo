# =============================================================================
# MODULE: gcs_bucket — variables.tf
# PURPOSE: Declares all input variables this module accepts.
#          Think of these as the "function arguments" of the module.
#          The caller (environments/dev/main.tf) must supply required ones.
# =============================================================================

# -----------------------------------------------------------------------------
# REQUIRED VARIABLES — must be provided by the caller, no default values
# -----------------------------------------------------------------------------

variable "bucket_name" {
  description = "The globally unique name for the GCS bucket. Must be unique across all of GCP."
  type        = string

  # Validation ensures the bucket name follows GCP naming rules
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9_-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be 3-63 characters, lowercase letters, numbers, hyphens, underscores only."
  }
}

variable "project_id" {
  description = "The GCP project ID where the bucket will be created."
  type        = string
}

variable "environment" {
  description = "The deployment environment (dev, staging, prod). Used for labeling."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

# -----------------------------------------------------------------------------
# OPTIONAL VARIABLES — have default values, caller can override them
# -----------------------------------------------------------------------------

variable "location" {
  description = <<EOT
  The geographic location for the bucket.
  Multi-region: US, EU, ASIA
  Dual-region:  NAM4, EUR4
  Single-region: us-central1, europe-west1, etc.
  EOT
  type        = string
  default     = "US"
}

variable "storage_class" {
  description = <<EOT
  The storage class for the bucket. Options:
  STANDARD   - Frequently accessed data (default)
  NEARLINE   - Accessed less than once a month
  COLDLINE   - Accessed less than once a quarter
  ARCHIVE    - Accessed less than once a year (cheapest)
  EOT
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "NEARLINE", "COLDLINE", "ARCHIVE"], var.storage_class)
    error_message = "Storage class must be one of: STANDARD, NEARLINE, COLDLINE, ARCHIVE."
  }
}

variable "versioning_enabled" {
  description = "Whether to enable object versioning. Recommended for prod environments."
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = <<EOT
  If true, Terraform will delete all objects in the bucket before destroying it.
  WARNING: Set to false in prod to prevent accidental data loss.
  EOT
  type        = bool
  default     = false
}

variable "lifecycle_age_days" {
  description = "Number of days after which objects are transitioned to NEARLINE storage class."
  type        = number
  default     = 30
}

variable "kms_key_name" {
  description = <<EOT
  The Cloud KMS key to use for encryption.
  Format: projects/{project}/locations/{location}/keyRings/{keyRing}/cryptoKeys/{cryptoKey}
  Leave empty to use Google-managed encryption (default).
  EOT
  type        = string
  default     = ""
}

variable "additional_labels" {
  description = "Additional labels to apply to the bucket. Merged with default labels."
  type        = map(string)
  default     = {}
}

variable "iam_bindings" {
  description = <<EOT
  IAM role bindings for the bucket.
  Key   = IAM role (e.g. "roles/storage.objectViewer")
  Value = list of members (e.g. ["serviceAccount:sa@project.iam.gserviceaccount.com"])

  Example:
  iam_bindings = {
    "roles/storage.objectViewer" = ["serviceAccount:reader@myproject.iam.gserviceaccount.com"]
    "roles/storage.objectAdmin"  = ["serviceAccount:writer@myproject.iam.gserviceaccount.com"]
  }
  EOT
  type        = map(list(string))
  default     = {}
}
