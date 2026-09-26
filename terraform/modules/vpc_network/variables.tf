# =============================================================================
# MODULE: vpc_network — variables.tf
# PURPOSE: All input variables this module accepts.
# =============================================================================

# -----------------------------------------------------------------------------
# REQUIRED VARIABLES
# -----------------------------------------------------------------------------

variable "vpc_name" {
  description = "Name of the VPC network. Used as a prefix for all child resources (subnets, firewall rules, NAT)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,61}[a-z0-9]$", var.vpc_name))
    error_message = "VPC name must be lowercase letters, numbers, hyphens only, 3-63 chars."
  }
}

variable "project_id" {
  description = "The GCP project ID where the VPC will be created."
  type        = string
}

variable "environment" {
  description = "The deployment environment (dev, staging, prod). Used in descriptions and labels."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "primary_region" {
  description = "The primary GCP region for Cloud Router and Cloud NAT. e.g. us-central1"
  type        = string
}

variable "subnets" {
  description = <<EOT
  List of subnet configurations to create inside the VPC.
  Each subnet object supports:
    - name            (required) : unique subnet name
    - region          (required) : GCP region e.g. "us-central1"
    - cidr_range      (required) : primary CIDR e.g. "10.0.1.0/24"
    - secondary_ranges (optional): list of secondary ranges for GKE pods/services

  Example:
  subnets = [
    {
      name       = "dev-subnet-uc1"
      region     = "us-central1"
      cidr_range = "10.0.1.0/24"
      secondary_ranges = [
        { range_name = "pods",     cidr_range = "10.1.0.0/16" },
        { range_name = "services", cidr_range = "10.2.0.0/20" }
      ]
    }
  ]
  EOT
  type = list(object({
    name       = string
    region     = string
    cidr_range = string
    secondary_ranges = optional(list(object({
      range_name = string
      cidr_range = string
    })), [])
  }))
}

# -----------------------------------------------------------------------------
# OPTIONAL VARIABLES
# -----------------------------------------------------------------------------

variable "routing_mode" {
  description = <<EOT
  VPC routing mode:
  REGIONAL - routes only shared within the same region (default, recommended)
  GLOBAL   - routes shared across all regions (useful for multi-region setups)
  EOT
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "GLOBAL"], var.routing_mode)
    error_message = "Routing mode must be REGIONAL or GLOBAL."
  }
}

variable "enable_flow_logs" {
  description = "Whether to enable VPC Flow Logs on all subnets. Recommended for prod. Adds cost."
  type        = bool
  default     = false
}

variable "ssh_source_ranges" {
  description = <<EOT
  CIDR ranges allowed to SSH into VMs tagged with 'ssh-allowed'.
  Dev:  ["0.0.0.0/0"]              (open for convenience)
  Prod: ["10.0.0.0/8"]             (only internal/corporate IPs)
  EOT
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
