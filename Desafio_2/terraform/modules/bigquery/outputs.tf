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

output "taxi_trips_table_id" {
  description = "Full table ID for taxi_trips"
  value       = "${var.project_id}.${google_bigquery_dataset.raw_data.dataset_id}.${google_bigquery_table.taxi_trips.table_id}"
}

output "weather_daily_table_id" {
  description = "Full table ID for weather_daily"
  value       = "${var.project_id}.${google_bigquery_dataset.raw_data.dataset_id}.${google_bigquery_table.weather_daily.table_id}"
}

# ------------------------------------------------------------------------------
# Data Transfer Outputs
# ------------------------------------------------------------------------------
output "taxi_transfer_name" {
  description = "Name of the taxi data transfer configuration"
  value       = var.enable_taxi_transfer ? google_bigquery_data_transfer_config.taxi_transfer[0].display_name : null
}

output "taxi_transfer_id" {
  description = "ID of the taxi data transfer configuration"
  value       = var.enable_taxi_transfer ? google_bigquery_data_transfer_config.taxi_transfer[0].name : null
}
