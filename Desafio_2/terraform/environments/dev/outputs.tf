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
# PASO 2: Cloud Functions - Descomentar cuando se habilite el módulo
# ==============================================================================
# output "weather_trigger_topic" {
#   description = "Pub/Sub topic to trigger weather ingestion"
#   value       = module.cloud_functions.weather_trigger_topic_name
# }
#
# output "dbt_trigger_topic" {
#   description = "Pub/Sub topic to trigger dbt"
#   value       = module.cloud_functions.dbt_trigger_topic_name
# }
#
# output "functions_source_bucket" {
#   description = "GCS bucket for function source code"
#   value       = module.cloud_functions.functions_source_bucket
# }

# ==============================================================================
# PASO 3: Cloud Scheduler - Descomentar cuando se habilite el módulo
# ==============================================================================
# output "scheduler_job_name" {
#   description = "Name of the Cloud Scheduler job"
#   value       = module.cloud_scheduler.job_name
# }

# ==============================================================================
# PASO 4: IAM - Descomentar cuando se habilite el módulo
# ==============================================================================
# output "cloud_functions_sa" {
#   description = "Cloud Functions service account email"
#   value       = module.iam.cloud_functions_sa_email
# }
#
# output "looker_studio_sa" {
#   description = "Looker Studio service account email"
#   value       = module.iam.looker_studio_sa_email
# }
