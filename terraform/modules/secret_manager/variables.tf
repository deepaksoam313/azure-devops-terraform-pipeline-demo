# =============================================================================
# MODULE: secret_manager — variables.tf
# =============================================================================

variable "project_id" {
  description = "The GCP project ID where secrets will be created."
  type        = string
}

variable "environment" {
  description = "The deployment environment (dev, staging, prod). Used for labeling secrets."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "secrets" {
  description = <<EOT
  Map of secrets to create in GCP Secret Manager.
  Key   = secret ID (name) — used to reference the secret
  Value = object with:
    value     (required) : the actual secret value — marked sensitive
    type      (optional) : label for the secret type e.g. "database", "api-key"
    accessors (optional) : list of IAM members who can read this secret
                           e.g. ["serviceAccount:app@project.iam.gserviceaccount.com"]

  Example:
  secrets = {
    "db-password" = {
      value     = "super-secret-password"
      type      = "database"
      accessors = ["serviceAccount:app-sa@myproject.iam.gserviceaccount.com"]
    }
    "api-key" = {
      value     = "my-api-key-12345"
      type      = "api-key"
      accessors = []
    }
  }

  IMPORTANT: In practice, you do NOT hardcode values here.
  Pass them via Azure DevOps pipeline variables (marked secret):
    -var="secrets={\"db-password\"={value=\"$(DB_PASSWORD)\"}}"
  EOT

  type = map(object({
    value     = string
    type      = optional(string, "generic")
    accessors = optional(list(string), [])
  }))

  sensitive = true   # marks entire variable as sensitive — won't appear in logs
}
