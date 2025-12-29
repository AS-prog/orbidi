# ==============================================================================
# Cloud Functions Module - Outputs
# ==============================================================================

# ------------------------------------------------------------------------------
# Weather Function Outputs
# ------------------------------------------------------------------------------
output "function_name" {
  description = "Name of the deployed Weather Cloud Function"
  value       = google_cloudfunctions2_function.ingest_weather.name
}

output "function_uri" {
  description = "URI of the Weather Cloud Function (HTTPS endpoint)"
  value       = google_cloudfunctions2_function.ingest_weather.service_config[0].uri
}

output "function_service_account" {
  description = "Service account used by the functions"
  value       = local.service_account_email
}

# ------------------------------------------------------------------------------
# Taxis Function Outputs
# ------------------------------------------------------------------------------
output "taxis_function_name" {
  description = "Name of the deployed Taxis Cloud Function"
  value       = google_cloudfunctions2_function.ingest_taxis.name
}

output "taxis_function_uri" {
  description = "URI of the Taxis Cloud Function (HTTPS endpoint)"
  value       = google_cloudfunctions2_function.ingest_taxis.service_config[0].uri
}

# ------------------------------------------------------------------------------
# Storage Outputs
# ------------------------------------------------------------------------------
output "source_bucket" {
  description = "GCS bucket containing function source code"
  value       = google_storage_bucket.function_source.name
}

output "source_object" {
  description = "GCS object path of the weather function source"
  value       = google_storage_bucket_object.weather_function_zip.name
}

output "taxis_source_object" {
  description = "GCS object path of the taxis function source"
  value       = google_storage_bucket_object.taxis_function_zip.name
}

output "data_landing_bucket" {
  description = "GCS bucket for landing data (Parquet files)"
  value       = google_storage_bucket.data_landing.name
}

output "data_landing_bucket_url" {
  description = "GCS URL for landing data bucket"
  value       = google_storage_bucket.data_landing.url
}
