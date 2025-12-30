# ==============================================================================
# Cloud Build Module - Outputs
# ==============================================================================

output "trigger_id" {
  description = "ID del Cloud Build trigger"
  value       = google_cloudbuild_trigger.dbt_run.trigger_id
}

output "trigger_name" {
  description = "Nombre del Cloud Build trigger"
  value       = google_cloudbuild_trigger.dbt_run.name
}

output "scheduler_job_name" {
  description = "Nombre del Cloud Scheduler job"
  value       = google_cloud_scheduler_job.dbt_trigger.name
}

output "service_account_email" {
  description = "Email del Service Account de Cloud Build"
  value       = google_service_account.cloud_build_dbt.email
}
