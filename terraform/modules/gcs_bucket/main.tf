# =============================================================================
# MODULE: gcs_bucket
# PURPOSE: Creates a Google Cloud Storage bucket with enterprise-grade settings
# CALLED BY: environments/dev/main.tf, environments/prod/main.tf
# =============================================================================

# -----------------------------------------------------------------------------
# TERRAFORM & PROVIDER REQUIREMENTS
# Specifies which version of Terraform and the Google provider this module needs
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
# RESOURCE: google_storage_bucket
# This is the actual GCS bucket resource that gets created in GCP.
# All values come from var.* — meaning they are passed in from the caller
# (environments/dev/main.tf or environments/prod/main.tf)
# -----------------------------------------------------------------------------
resource "google_storage_bucket" "this" {
  name          = var.bucket_name   # unique name for the bucket
  location      = var.location      # e.g. "US", "ASIA", "EU", or specific region
  project       = var.project_id    # which GCP project to create this in
  storage_class = var.storage_class # STANDARD, NEARLINE, COLDLINE, ARCHIVE
  force_destroy = var.force_destroy # if true, deletes all objects when bucket is destroyed

  # ---------------------------------------------------------------------------
  # UNIFORM BUCKET-LEVEL ACCESS
  # Disables per-object ACLs. Enforces IAM-only access control.
  # This is a security best practice for enterprise environments.
  # ---------------------------------------------------------------------------
  uniform_bucket_level_access = true

  # ---------------------------------------------------------------------------
  # VERSIONING
  # Keeps previous versions of objects when they are overwritten or deleted.
  # Useful for audit trails, backups, and accidental deletion recovery.
  # ---------------------------------------------------------------------------
  versioning {
    enabled = var.versioning_enabled
  }

  # ---------------------------------------------------------------------------
  # LIFECYCLE RULE
  # Automatically moves objects to cheaper storage class after N days.
  # Saves cost for infrequently accessed data.
  # ---------------------------------------------------------------------------
  lifecycle_rule {
    condition {
      age = var.lifecycle_age_days # number of days before transitioning
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE" # move to cheaper storage after N days
    }
  }

  # ---------------------------------------------------------------------------
  # ENCRYPTION
  # Uses a Customer-Managed Encryption Key (CMEK) from GCP Cloud KMS.
  # If no KMS key is provided, Google-managed encryption is used (default).
  # ---------------------------------------------------------------------------
  dynamic "encryption" {
    for_each = var.kms_key_name != "" ? [1] : []
    content {
      default_kms_key_name = var.kms_key_name
    }
  }

  # ---------------------------------------------------------------------------
  # LABELS
  # Key-value pairs attached to the bucket for organization, billing tracking,
  # and filtering in GCP console. Merged with environment-specific labels.
  # ---------------------------------------------------------------------------
  labels = merge(
    {
      environment = var.environment
      managed_by  = "terraform"
      module      = "gcs_bucket"
    },
    var.additional_labels
  )
}

# -----------------------------------------------------------------------------
# RESOURCE: google_storage_bucket_iam_binding
# Controls WHO can access this bucket.
# Grants the specified roles to the specified members (service accounts, users).
# Only created if var.iam_bindings is provided.
# -----------------------------------------------------------------------------
resource "google_storage_bucket_iam_binding" "bindings" {
  for_each = var.iam_bindings # loop over each role → members mapping

  bucket  = google_storage_bucket.this.name
  role    = each.key   # e.g. "roles/storage.objectViewer"
  members = each.value # e.g. ["serviceAccount:sa@project.iam.gserviceaccount.com"]
}
