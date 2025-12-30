# ==============================================================================
# Terraform Outputs - Development Environment
# ==============================================================================

# ==============================================================================
# PASO 1: BigQuery (Capa Raw)
# ==============================================================================
output "raw_data_dataset" {
  description = "BigQuery raw_data dataset ID"
  value       = module.bigquery.raw_data_dataset_id
}

output "silver_data_dataset" {
  description = "BigQuery silver_data dataset ID"
  value       = module.bigquery.silver_data_dataset_id
}

output "analytics_dataset" {
  description = "BigQuery analytics dataset ID"
  value       = module.bigquery.analytics_dataset_id
}

output "taxi_trips_table" {
  description = "Full table ID for taxi trips"
  value       = module.bigquery.taxi_trips_table_id
}

output "weather_daily_table" {
  description = "Full table ID for weather data"
  value       = module.bigquery.weather_daily_table_id
}

# ==============================================================================
# Cloud Functions
# ==============================================================================
output "weather_function_name" {
  description = "Name of the weather ingestion function"
  value       = module.cloud_functions.function_name
}

output "weather_function_uri" {
  description = "HTTPS endpoint of the weather function"
  value       = module.cloud_functions.function_uri
}

output "weather_function_sa" {
  description = "Service account used by the weather function"
  value       = module.cloud_functions.function_service_account
}

output "functions_source_bucket" {
  description = "GCS bucket for function source code"
  value       = module.cloud_functions.source_bucket
}

output "data_landing_bucket" {
  description = "GCS bucket for data landing (Parquet files)"
  value       = module.cloud_functions.data_landing_bucket
}

output "weather_external_table" {
  description = "External table for weather data (reads from Parquet)"
  value       = "${var.project_id}.${module.bigquery.raw_data_dataset_id}.${google_bigquery_table.weather_external.table_id}"
}

# ==============================================================================
# Cloud Scheduler
# ==============================================================================
output "scheduler_job_name" {
  description = "Name of the Cloud Scheduler job"
  value       = module.cloud_scheduler.job_name
}

output "scheduler_schedule" {
  description = "Cron schedule of the job"
  value       = module.cloud_scheduler.schedule
}

output "scheduler_timezone" {
  description = "Timezone of the job"
  value       = module.cloud_scheduler.timezone
}

# ==============================================================================
# Data Security (Column-Level Security)
# ==============================================================================
output "taxonomy_id" {
  description = "Data Catalog Taxonomy ID"
  value       = module.data_security.taxonomy_id
}

output "payment_policy_tag" {
  description = "Policy Tag for payment_type column"
  value       = module.data_security.payment_policy_tag_name
}

# ==============================================================================
# CI/CD - GitHub Actions
# ==============================================================================
output "github_actions_sa_email" {
  description = "Email of the GitHub Actions service account"
  value       = module.cicd.service_account_email
}

output "github_actions_key_path" {
  description = "Path to the GitHub Actions service account key file"
  value       = module.cicd.key_file_path
}

# ==============================================================================
# Cloud Build - dbt Automation
# ==============================================================================
output "dbt_trigger_id" {
  description = "ID del Cloud Build trigger para dbt"
  value       = module.cloud_build.trigger_id
}

output "dbt_scheduler_job" {
  description = "Nombre del Cloud Scheduler job para dbt"
  value       = module.cloud_build.scheduler_job_name
}

output "dbt_service_account" {
  description = "Service Account usado por Cloud Build para dbt"
  value       = module.cloud_build.service_account_email
}
