# =============================================================================
# FILE: environments/prod/backend.tf
# PURPOSE: Tells Terraform WHERE to store the state file for PROD environment.
#
# KEY DIFFERENCE FROM DEV:
# ------------------------
# prefix = "prod" → state stored at gs://bucket/prod/terraform.tfstate
# This is COMPLETELY SEPARATE from dev state (prefix = "dev")
# You can NEVER accidentally apply dev state to prod or vice versa.
#
# ADDITIONAL PROD RECOMMENDATION:
# --------------------------------
# Enable Object Versioning on the GCS state bucket so you can
# roll back to a previous state if something goes wrong:
#   gcloud storage buckets update gs://YOUR_TFSTATE_BUCKET \
#     --versioning
#
# Also enable Bucket Lock / Retention Policy on the state bucket
# to prevent accidental state deletion in prod.
# =============================================================================

terraform {
  backend "gcs" {
    # Same bucket as dev — but DIFFERENT prefix = different state file
    bucket = "YOUR_TFSTATE_BUCKET"   # REPLACE with your actual tfstate bucket name

    # prod state lives at: gs://YOUR_TFSTATE_BUCKET/prod/terraform.tfstate
    # dev  state lives at: gs://YOUR_TFSTATE_BUCKET/dev/terraform.tfstate
    prefix = "prod"
  }
}
