# =============================================================================
# MODULE: gcs_bucket — outputs.tf
# PURPOSE: Declares what this module RETURNS after resources are created.
#          Other modules or environments can reference these output values.
#          Think of these as the "return values" of the module.
#
# USAGE EXAMPLE (in environments/dev/main.tf):
#   output "bucket_url" {
#     value = module.app_bucket.bucket_url
#   }
# =============================================================================

output "bucket_name" {
  description = "The name of the created GCS bucket."
  value       = google_storage_bucket.this.name
}

output "bucket_id" {
  description = "The ID of the bucket in format: project/bucket_name"
  value       = google_storage_bucket.this.id
}

output "bucket_url" {
  description = "The base URL of the bucket in format: gs://bucket_name"
  value       = google_storage_bucket.this.url
}

output "bucket_self_link" {
  description = "The URI of the created bucket. Used for referencing the bucket in other GCP resources."
  value       = google_storage_bucket.this.self_link
}

output "bucket_location" {
  description = "The geographic location of the bucket."
  value       = google_storage_bucket.this.location
}

output "storage_class" {
  description = "The storage class of the bucket."
  value       = google_storage_bucket.this.storage_class
}
