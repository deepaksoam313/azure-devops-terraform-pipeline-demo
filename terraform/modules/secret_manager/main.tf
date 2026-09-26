# =============================================================================
# MODULE: secret_manager
# PURPOSE: Creates and manages secrets in GCP Secret Manager.
#          Provides a secure way to store and access sensitive values like:
#          - Database passwords
#          - API keys
#          - Connection strings
#          - Service account credentials
#
# HOW IT FITS IN THE ARCHITECTURE:
#
#   Azure DevOps Pipeline
#        │
#        │  Secret: GCP_SA_KEY (stored in ADO variable group)
#        │  Used ONLY to authenticate Terraform to GCP
#        ▼
#   Terraform runs
#        │
#        ├── Creates secrets IN GCP Secret Manager (this module)
#        │
#        └── Other resources FETCH secrets FROM GCP Secret Manager at runtime
#
# TWO OPERATIONS THIS MODULE HANDLES:
#   1. CREATE  a secret container + store its value
#   2. READ    a secret value (via data source) for use in other resources
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
# RESOURCE: google_secret_manager_secret
# Creates the SECRET CONTAINER in GCP Secret Manager.
# Think of this as creating a "folder" that holds versions of the secret value.
# The actual value is stored separately in google_secret_manager_secret_version.
#
# WHY SEPARATE CONTAINER AND VALUE?
# Secret Manager supports versioning — you can rotate secrets by adding
# a new version without deleting the old one. Old versions can be disabled
# or destroyed independently.
# -----------------------------------------------------------------------------
resource "google_secret_manager_secret" "secrets" {
  # for_each creates one secret container per entry in var.secrets map
  for_each = var.secrets

  secret_id = each.key # the name/ID of the secret e.g. "db-password"
  project   = var.project_id

  # -------------------------------------------------------------------------
  # REPLICATION POLICY
  # Controls in which GCP regions the secret is replicated/stored.
  # automatic = GCP decides (recommended, simpler)
  # user_managed = you specify exact regions (for compliance/data residency)
  # -------------------------------------------------------------------------
  replication {
    auto {} # automatic replication — GCP manages it across regions
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    secret_type = lookup(each.value, "type", "generic") # e.g. "database", "api-key"
  }
}

# -----------------------------------------------------------------------------
# RESOURCE: google_secret_manager_secret_version
# Stores the ACTUAL SECRET VALUE inside the container created above.
# Each time you update a secret, a new version is created (v1, v2, v3...).
# The latest enabled version is returned when the secret is accessed.
#
# IMPORTANT: The secret_data (actual value) is stored encrypted in GCP.
# Terraform stores it in state — so your STATE FILE must also be secured
# (which it is, since it's in a GCS bucket with restricted IAM access).
# -----------------------------------------------------------------------------
resource "google_secret_manager_secret_version" "versions" {
  for_each = var.secrets

  # Links to the secret container created above
  secret = google_secret_manager_secret.secrets[each.key].id

  # The actual secret value — comes from var.secrets[key].value
  # This value is marked sensitive so Terraform won't print it in logs
  secret_data = each.value.value

  # Automatically enable this version (makes it the active version)
  enabled = true
}

# -----------------------------------------------------------------------------
# RESOURCE: google_secret_manager_secret_iam_binding
# Controls WHO can ACCESS each secret.
# Only the specified service accounts/users can read the secret value.
# Everyone else is denied by default (GCP's default deny principle).
#
# PRINCIPLE OF LEAST PRIVILEGE:
# - App service account gets secretAccessor (read only)
# - Pipeline service account gets secretVersionManager (can add versions)
# - No one gets secretAdmin unless absolutely necessary
# -----------------------------------------------------------------------------
resource "google_secret_manager_secret_iam_binding" "accessors" {
  # Only create IAM bindings for secrets that have accessors defined
  for_each = {
    for k, v in var.secrets : k => v
    if length(lookup(v, "accessors", [])) > 0
  }

  project   = var.project_id
  secret_id = google_secret_manager_secret.secrets[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor" # read-only access to secret value

  # List of who can access this secret
  # e.g. ["serviceAccount:app@project.iam.gserviceaccount.com"]
  members = each.value.accessors
}
