# ==============================================================================
# Cloud Scheduler Module - Outputs
# ==============================================================================

# ------------------------------------------------------------------------------
# Weather Job Outputs
# ------------------------------------------------------------------------------
output "weather_job_name" {
  description = "Name of the Weather Cloud Scheduler job"
  value       = google_cloud_scheduler_job.weather_ingestion.name
}

output "weather_job_id" {
  description = "Full ID of the Weather Cloud Scheduler job"
  value       = google_cloud_scheduler_job.weather_ingestion.id
}

output "weather_schedule" {
  description = "Cron schedule of the weather job"
  value       = google_cloud_scheduler_job.weather_ingestion.schedule
}

output "weather_timezone" {
  description = "Timezone of the weather job"
  value       = google_cloud_scheduler_job.weather_ingestion.time_zone
}

# ------------------------------------------------------------------------------
# Taxis Job Outputs
# ------------------------------------------------------------------------------
output "taxis_job_name" {
  description = "Name of the Taxis Cloud Scheduler job"
  value       = google_cloud_scheduler_job.taxis_ingestion.name
}

output "taxis_job_id" {
  description = "Full ID of the Taxis Cloud Scheduler job"
  value       = google_cloud_scheduler_job.taxis_ingestion.id
}

output "taxis_schedule" {
  description = "Cron schedule of the taxis job"
  value       = google_cloud_scheduler_job.taxis_ingestion.schedule
}

output "taxis_timezone" {
  description = "Timezone of the taxis job"
  value       = google_cloud_scheduler_job.taxis_ingestion.time_zone
}

# ------------------------------------------------------------------------------
# Legacy outputs (for backward compatibility)
# ------------------------------------------------------------------------------
output "job_name" {
  description = "Name of the Weather Cloud Scheduler job (deprecated, use weather_job_name)"
  value       = google_cloud_scheduler_job.weather_ingestion.name
}

output "job_id" {
  description = "Full ID of the Weather Cloud Scheduler job (deprecated, use weather_job_id)"
  value       = google_cloud_scheduler_job.weather_ingestion.id
}

output "schedule" {
  description = "Cron schedule of the weather job (deprecated, use weather_schedule)"
  value       = google_cloud_scheduler_job.weather_ingestion.schedule
}

output "timezone" {
  description = "Timezone of the weather job (deprecated, use weather_timezone)"
  value       = google_cloud_scheduler_job.weather_ingestion.time_zone
}
