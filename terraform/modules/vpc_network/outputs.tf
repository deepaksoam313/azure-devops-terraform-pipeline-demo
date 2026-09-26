# =============================================================================
# MODULE: vpc_network — outputs.tf
# PURPOSE: Returns key attributes of the created VPC so other modules
#          and environments can reference them without hardcoding.
#
# USAGE EXAMPLE (in environments/dev/main.tf):
#   module "vpc" { source = "../../modules/vpc_network" ... }
#
#   # Another module referencing the VPC output:
#   module "gke_cluster" {
#     network    = module.vpc.vpc_id
#     subnetwork = module.vpc.subnet_ids["dev-subnet-uc1"]
#   }
# =============================================================================

output "vpc_id" {
  description = "The unique ID of the VPC network."
  value       = google_compute_network.this.id
}

output "vpc_name" {
  description = "The name of the VPC network."
  value       = google_compute_network.this.name
}

output "vpc_self_link" {
  description = "The URI of the VPC. Used when referencing the network in other GCP resources like GKE, Cloud SQL."
  value       = google_compute_network.this.self_link
}

output "subnet_ids" {
  description = "Map of subnet name → subnet ID. Use to reference subnets in other modules."
  value       = { for k, v in google_compute_subnetwork.subnets : k => v.id }
}

output "subnet_self_links" {
  description = "Map of subnet name → subnet self_link. Used for GKE node pool subnet references."
  value       = { for k, v in google_compute_subnetwork.subnets : k => v.self_link }
}

output "subnet_cidr_ranges" {
  description = "Map of subnet name → primary CIDR range."
  value       = { for k, v in google_compute_subnetwork.subnets : k => v.ip_cidr_range }
}

output "router_name" {
  description = "The name of the Cloud Router. Used for VPN and Interconnect attachments."
  value       = google_compute_router.router.name
}

output "nat_name" {
  description = "The name of the Cloud NAT gateway."
  value       = google_compute_router_nat.nat.name
}
