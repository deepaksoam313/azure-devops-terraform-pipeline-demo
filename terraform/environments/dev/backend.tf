# =============================================================================
# FILE: environments/dev/backend.tf
# PURPOSE: Tells Terraform WHERE to store the state file for the dev environment.
#
# WHY REMOTE STATE?
# -----------------
# By default, Terraform stores state locally (terraform.tfstate on your machine).
# That's fine for solo work but breaks in a team/pipeline because:
#   1. Azure DevOps pipeline runs on a fresh VM every time — no local state
#   2. Two engineers running terraform simultaneously would corrupt state
#   3. No shared visibility into what's deployed
#
# SOLUTION: Store state in a GCS bucket (remote backend).
# Everyone (including the pipeline) reads/writes the SAME state file.
#
# STATE FILE LOCATION IN GCS:
#   gs://YOUR_TFSTATE_BUCKET/dev/terraform.tfstate
#
# PRE-REQUISITE:
# The GCS bucket for state must exist BEFORE running terraform init.
# Create it manually once:
#   gcloud storage buckets create gs://YOUR_TFSTATE_BUCKET \
#     --location=US \
#     --uniform-bucket-level-access
#
# LOCKING:
# GCS backend supports state locking natively.
# If two processes try to run terraform at the same time,
# the second one waits until the first releases the lock.
# =============================================================================

terraform {
  backend "gcs" {
    # -------------------------------------------------------------------------
    # bucket: The GCS bucket that stores the state file.
    # REPLACE "YOUR_TFSTATE_BUCKET" with your actual bucket name.
    # Naming convention: <company>-<project>-tfstate
    # Example: mycompany-myproject-tfstate
    # -------------------------------------------------------------------------
    bucket = "YOUR_TFSTATE_BUCKET"

    # -------------------------------------------------------------------------
    # prefix: The folder path inside the bucket for THIS environment's state.
    # Each environment has its own prefix → completely isolated state files.
    #   dev  state: gs://bucket/dev/terraform.tfstate
    #   prod state: gs://bucket/prod/terraform.tfstate
    # -------------------------------------------------------------------------
    prefix = "dev"
  }
}
