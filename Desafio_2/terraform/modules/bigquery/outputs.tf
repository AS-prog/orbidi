# ==============================================================================
# BigQuery Module - Outputs
# ==============================================================================

output "raw_data_dataset_id" {
  description = "The ID of the raw_data dataset"
  value       = google_bigquery_dataset.raw_data.dataset_id
}

output "silver_data_dataset_id" {
  description = "The ID of the silver_data dataset"
  value       = google_bigquery_dataset.silver_data.dataset_id
}

output "analytics_dataset_id" {
  description = "The ID of the analytics dataset"
  value       = google_bigquery_dataset.analytics.dataset_id
}
