# ==============================================================================
# Cloud Scheduler Module - Outputs
# ==============================================================================

output "job_name" {
  description = "Name of the Cloud Scheduler job"
  value       = google_cloud_scheduler_job.weather_ingestion.name
}

output "job_id" {
  description = "Full ID of the Cloud Scheduler job"
  value       = google_cloud_scheduler_job.weather_ingestion.id
}

output "schedule" {
  description = "Cron schedule of the job"
  value       = google_cloud_scheduler_job.weather_ingestion.schedule
}

output "timezone" {
  description = "Timezone of the job"
  value       = google_cloud_scheduler_job.weather_ingestion.time_zone
}
