# ==============================================================================
# Cloud Functions Module - Outputs
# ==============================================================================

output "function_name" {
  description = "Name of the deployed Cloud Function"
  value       = google_cloudfunctions2_function.ingest_weather.name
}

output "function_uri" {
  description = "URI of the Cloud Function (HTTPS endpoint)"
  value       = google_cloudfunctions2_function.ingest_weather.service_config[0].uri
}

output "function_service_account" {
  description = "Service account used by the function"
  value       = local.service_account_email
}

output "source_bucket" {
  description = "GCS bucket containing function source code"
  value       = google_storage_bucket.function_source.name
}

output "source_object" {
  description = "GCS object path of the function source"
  value       = google_storage_bucket_object.weather_function_zip.name
}

output "data_landing_bucket" {
  description = "GCS bucket for landing data (Parquet files)"
  value       = google_storage_bucket.data_landing.name
}

output "data_landing_bucket_url" {
  description = "GCS URL for landing data bucket"
  value       = google_storage_bucket.data_landing.url
}
