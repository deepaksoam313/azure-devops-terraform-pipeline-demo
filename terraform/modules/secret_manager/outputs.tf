# =============================================================================
# MODULE: secret_manager — outputs.tf
# PURPOSE: Returns secret resource IDs and names so other modules can
#          REFERENCE secrets without needing to know the full path.
#
# NOTE: Secret VALUES are never output — only the resource identifiers.
#       To READ a secret value in another module, use a data source:
#
#   data "google_secret_manager_secret_version" "db_pass" {
#     secret  = module.secrets.secret_ids["db-password"]
#     project = var.project_id
#   }
#   # Then use: data.google_secret_manager_secret_version.db_pass.secret_data
# =============================================================================

output "secret_ids" {
  description = <<EOT
  Map of secret name → secret resource ID.
  Use this to reference secrets in other modules via data sources.
  Example: module.secrets.secret_ids["db-password"]
  EOT
  value       = { for k, v in google_secret_manager_secret.secrets : k => v.id }
}

output "secret_names" {
  description = "Map of secret name → secret_id (short name). Used for gcloud CLI references."
  value       = { for k, v in google_secret_manager_secret.secrets : k => v.secret_id }
}

output "secret_version_ids" {
  description = "Map of secret name → version resource ID. Points to the latest created version."
  value       = { for k, v in google_secret_manager_secret_version.versions : k => v.id }
  sensitive   = true   # marked sensitive to prevent accidental exposure in logs
}
