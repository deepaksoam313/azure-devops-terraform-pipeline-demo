# =============================================================================
# FILE: environments/dev/variables.tf
# PURPOSE: Declares all variables used in THIS environment's main.tf.
#          These are declared here but their VALUES come from terraform.tfvars
#          (or from the Azure DevOps pipeline for sensitive values).
#
# FLOW:
#   terraform.tfvars  ──supplies values──►  variables.tf  ──used in──►  main.tf
# =============================================================================

# -----------------------------------------------------------------------------
# GCP PROJECT SETTINGS
# -----------------------------------------------------------------------------

variable "project_id" {
  description = "The GCP project ID for the dev environment. e.g. my-project-dev-123456"
  type        = string
}

variable "region" {
  description = "The primary GCP region for all resources in dev. e.g. us-central1"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name — always 'dev' for this folder. Used for labeling resources."
  type        = string
  default     = "dev"
}

# -----------------------------------------------------------------------------
# GCS BUCKET SETTINGS
# -----------------------------------------------------------------------------

variable "app_bucket_name" {
  description = "Name of the application GCS bucket for dev. Must be globally unique across GCP."
  type        = string
}

variable "bucket_location" {
  description = "Geographic location for the GCS bucket. Multi-region US is default."
  type        = string
  default     = "US"
}

# -----------------------------------------------------------------------------
# VPC NETWORK SETTINGS
# -----------------------------------------------------------------------------

variable "vpc_name" {
  description = "Name of the VPC network for dev environment."
  type        = string
  default     = "dev-vpc"
}

variable "subnet_cidr" {
  description = "Primary CIDR range for the dev subnet. e.g. 10.0.1.0/24"
  type        = string
  default     = "10.0.1.0/24"
}

# -----------------------------------------------------------------------------
# SECURITY SETTINGS
# -----------------------------------------------------------------------------

variable "ssh_source_ranges" {
  description = <<EOT
  IP ranges allowed to SSH into dev VMs.
  In dev, this is open to all (0.0.0.0/0) for convenience.
  In prod, this will be locked to corporate IP ranges only.
  EOT
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
