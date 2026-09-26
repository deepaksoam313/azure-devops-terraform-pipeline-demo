# =============================================================================
# MODULE: vpc_network
# PURPOSE: Creates a GCP VPC network with subnets, firewall rules, and
#          Cloud NAT for private instances to reach the internet.
# CALLED BY: environments/dev/main.tf, environments/prod/main.tf
#
# ARCHITECTURE CREATED:
#
#   VPC Network
#   └── Subnet (private, with secondary ranges for GKE pods/services)
#       ├── Cloud Router       (needed for Cloud NAT)
#       ├── Cloud NAT          (allows private VMs to reach internet)
#       └── Firewall Rules
#           ├── allow-internal (VMs in VPC can talk to each other)
#           ├── allow-ssh      (SSH access — restricted by IP in prod)
#           └── deny-all-ingress (default deny everything else)
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
# RESOURCE: google_compute_network (VPC)
# The top-level network container. All subnets, VMs, etc. live inside this.
# auto_create_subnetworks = false means WE define the subnets manually (best practice).
# -----------------------------------------------------------------------------
resource "google_compute_network" "this" {
  name                            = var.vpc_name
  project                         = var.project_id
  auto_create_subnetworks         = false            # custom subnets only — no auto subnets
  routing_mode                    = var.routing_mode # REGIONAL or GLOBAL
  delete_default_routes_on_create = false            # keep default internet route
  description                     = "VPC network for ${var.environment} environment - managed by Terraform"
}

# -----------------------------------------------------------------------------
# RESOURCE: google_compute_subnetwork (Subnet)
# A subnet lives inside the VPC. VMs get IPs from the subnet's CIDR range.
# We use for_each to create multiple subnets from var.subnets list.
# -----------------------------------------------------------------------------
resource "google_compute_subnetwork" "subnets" {
  for_each = { for subnet in var.subnets : subnet.name => subnet }

  name                     = each.value.name
  project                  = var.project_id
  region                   = each.value.region
  network                  = google_compute_network.this.id # links to the VPC above
  ip_cidr_range            = each.value.cidr_range          # primary IP range e.g. 10.0.1.0/24
  private_ip_google_access = true                           # allows VMs without public IPs to reach Google APIs

  # ---------------------------------------------------------------------------
  # SECONDARY IP RANGES
  # Used by GKE (Kubernetes) for Pod and Service IPs.
  # If you're not using GKE, these are optional.
  # ---------------------------------------------------------------------------
  dynamic "secondary_ip_range" {
    for_each = lookup(each.value, "secondary_ranges", [])
    content {
      range_name    = secondary_ip_range.value.range_name
      ip_cidr_range = secondary_ip_range.value.cidr_range
    }
  }

  # ---------------------------------------------------------------------------
  # VPC FLOW LOGS
  # Captures network traffic metadata for security analysis and debugging.
  # Recommended for prod. Can be disabled in dev to save cost.
  # ---------------------------------------------------------------------------
  dynamic "log_config" {
    for_each = var.enable_flow_logs ? [1] : []
    content {
      aggregation_interval = "INTERVAL_5_SEC"
      flow_sampling        = 0.5 # sample 50% of flows
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }
}

# -----------------------------------------------------------------------------
# RESOURCE: google_compute_router (Cloud Router)
# Required by Cloud NAT. Acts as a virtual router at the region level.
# Manages dynamic routes (BGP) for VPN and Interconnect connections.
# -----------------------------------------------------------------------------
resource "google_compute_router" "router" {
  name    = "${var.vpc_name}-router"
  project = var.project_id
  region  = var.primary_region
  network = google_compute_network.this.id

  bgp {
    asn = 64514 # private ASN for BGP — used with VPN/Interconnect
  }
}

# -----------------------------------------------------------------------------
# RESOURCE: google_compute_router_nat (Cloud NAT)
# Allows VMs with ONLY private IPs to access the internet outbound.
# e.g. to pull Docker images, apt packages, call external APIs.
# WITHOUT this, private VMs cannot reach the internet at all.
# -----------------------------------------------------------------------------
resource "google_compute_router_nat" "nat" {
  name                               = "${var.vpc_name}-nat"
  project                            = var.project_id
  router                             = google_compute_router.router.name
  region                             = var.primary_region
  nat_ip_allocate_option             = "AUTO_ONLY"                     # GCP auto-assigns NAT IPs
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES" # NAT all subnets

  log_config {
    enable = true
    filter = "ERRORS_ONLY" # only log NAT errors (not all traffic)
  }
}

# -----------------------------------------------------------------------------
# FIREWALL RULE: allow-internal
# Allows all traffic BETWEEN resources inside the VPC.
# e.g. VM1 → VM2, VM → Cloud SQL, etc.
# Uses the VPC's internal IP ranges so only internal traffic is allowed.
# -----------------------------------------------------------------------------
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.vpc_name}-allow-internal"
  project = var.project_id
  network = google_compute_network.this.id

  description = "Allow all internal traffic within the VPC"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["0-65535"] # all TCP ports
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"] # all UDP ports
  }
  allow {
    protocol = "icmp" # allows ping between VMs
  }

  # Only allow traffic from within the VPC's own CIDR ranges
  source_ranges = [for subnet in var.subnets : subnet.cidr_range]
}

# -----------------------------------------------------------------------------
# FIREWALL RULE: allow-ssh
# Allows SSH (port 22) access to VMs.
# In dev: open to all IPs (0.0.0.0/0) for convenience
# In prod: restricted to specific corporate IP ranges via var.ssh_source_ranges
# -----------------------------------------------------------------------------
resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.vpc_name}-allow-ssh"
  project = var.project_id
  network = google_compute_network.this.id

  description = "Allow SSH access - restricted by source IP in prod"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_source_ranges # passed in from environment — different per env
  target_tags   = ["ssh-allowed"]       # only applies to VMs tagged with "ssh-allowed"
}

# -----------------------------------------------------------------------------
# FIREWALL RULE: deny-all-ingress
# Default deny rule — blocks all inbound traffic not matched by other rules.
# Lower priority (65534) means it only fires if NO other rule matches first.
# This is a security best practice (deny by default, allow explicitly).
# -----------------------------------------------------------------------------
resource "google_compute_firewall" "deny_all_ingress" {
  name    = "${var.vpc_name}-deny-all-ingress"
  project = var.project_id
  network = google_compute_network.this.id

  description = "Default deny all ingress — explicit allow rules override this"
  direction   = "INGRESS"
  priority    = 65534 # lowest priority — only fires if nothing else matches

  deny {
    protocol = "all" # deny ALL protocols
  }

  source_ranges = ["0.0.0.0/0"] # from anywhere
}
