# =============================================================================
# FILE: modules/secret_manager/data_sources.tf
# PURPOSE: Shows HOW TO READ secrets from GCP Secret Manager in Terraform.
#
# THIS FILE IS A REFERENCE/EXAMPLE — not executed directly by this module.
# Copy these data source patterns into YOUR environment's main.tf
# (environments/dev/main.tf or environments/prod/main.tf) when you need
# to fetch a secret value for use in another resource.
#
# =============================================================================
#
# PATTERN 1: Read a specific secret by name (most common)
# --------------------------------------------------------
# Use this when you need the VALUE of a secret in another resource.
#
# data "google_secret_manager_secret_version" "db_password" {
#   project = var.project_id
#   secret  = "db-password"    # the secret_id created by this module
#   version = "latest"         # always get the latest enabled version
# }
#
# # Use the fetched value in a resource:
# resource "google_sql_database_instance" "main" {
#   name = "my-database"
#   settings {
#     tier = "db-f1-micro"
#   }
#   # Inject the secret value — never hardcoded
#   root_password = data.google_secret_manager_secret_version.db_password.secret_data
# }
#
# =============================================================================
#
# PATTERN 2: Read multiple secrets at once using for_each
# -------------------------------------------------------
# Use this when you need several secrets in one place.
#
# locals {
#   secret_names = ["db-password", "api-key", "jwt-secret"]
# }
#
# data "google_secret_manager_secret_version" "all_secrets" {
#   for_each = toset(local.secret_names)
#   project  = var.project_id
#   secret   = each.key
#   version  = "latest"
# }
#
# # Access individual secrets:
# # data.google_secret_manager_secret_version.all_secrets["db-password"].secret_data
# # data.google_secret_manager_secret_version.all_secrets["api-key"].secret_data
#
# =============================================================================
#
# PATTERN 3: Reference a secret created by the secret_manager module
# ------------------------------------------------------------------
# When you call the secret_manager module AND need to read back a value:
#
# module "secrets" {
#   source      = "../../modules/secret_manager"
#   project_id  = var.project_id
#   environment = var.environment
#   secrets     = { ... }
# }
#
# data "google_secret_manager_secret_version" "db_pass" {
#   project = var.project_id
#   secret  = module.secrets.secret_names["db-password"]
#   version = "latest"
#
#   # Important: only read AFTER the secret is created
#   depends_on = [module.secrets]
# }
#
# =============================================================================
#
# PATTERN 4: Read a secret in Azure DevOps pipeline (without Terraform)
# ----------------------------------------------------------------------
# In azure-pipelines.yml you can fetch a secret directly using gcloud:
#
# - script: |
#     SECRET_VALUE=$(gcloud secrets versions access latest \
#       --secret="db-password" \
#       --project="$(GCP_PROJECT_ID)")
#     echo "##vso[task.setvariable variable=DB_PASSWORD;issecret=true]$SECRET_VALUE"
#   displayName: 'Fetch DB password from Secret Manager'
#
# Then use $(DB_PASSWORD) in subsequent pipeline steps as a masked variable.
#
# =============================================================================
#
# SECRET ROTATION WORKFLOW:
# --------------------------
# When you need to rotate a secret (change its value):
#
# OPTION A — Via Terraform (adds a new version):
#   1. Update the value in Azure DevOps pipeline variable
#   2. Pipeline runs terraform apply
#   3. New version created in Secret Manager
#   4. Old version automatically disabled
#
# OPTION B — Via gcloud CLI (manual rotation):
#   gcloud secrets versions add "db-password" \
#     --data-file=new_password.txt \
#     --project="YOUR_PROJECT_ID"
#
# OPTION C — Via GCP Console:
#   Secret Manager → select secret → "Add New Version"
# =============================================================================

# This file intentionally contains no executable Terraform code.
# It serves as inline documentation for secret consumption patterns.
