# ==============================================================================
# Data Security Module - Outputs
# ==============================================================================

output "taxonomy_id" {
  description = "The ID of the taxonomy"
  value       = google_data_catalog_taxonomy.main.id
}

output "taxonomy_name" {
  description = "The resource name of the taxonomy"
  value       = google_data_catalog_taxonomy.main.name
}

output "payment_policy_tag_id" {
  description = "The ID of the payment data policy tag"
  value       = google_data_catalog_policy_tag.payment_data.id
}

output "payment_policy_tag_name" {
  description = "The resource name of the payment data policy tag (for use in BigQuery schema)"
  value       = google_data_catalog_policy_tag.payment_data.name
}
