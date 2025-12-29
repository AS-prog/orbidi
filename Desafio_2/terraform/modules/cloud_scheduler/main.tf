# ==============================================================================
# Cloud Scheduler Module - Main
# ==============================================================================
# Ejecuta Cloud Functions según un schedule usando HTTP trigger
# ==============================================================================

# ------------------------------------------------------------------------------
# Cloud Scheduler Job para Weather Ingestion
# ------------------------------------------------------------------------------
resource "google_cloud_scheduler_job" "weather_ingestion" {
  name        = var.weather_job_name
  project     = var.project_id
  region      = var.region
  description = "Triggers weather ingestion daily using daily_offset mode"

  schedule  = var.weather_schedule
  time_zone = var.weather_timezone

  attempt_deadline = var.attempt_deadline

  retry_config {
    retry_count          = var.retry_count
    min_backoff_duration = "5s"
    max_backoff_duration = "300s"
    max_doublings        = 3
  }

  http_target {
    http_method = "GET"
    uri         = "${var.weather_function_uri}?mode=daily_offset"

    oidc_token {
      service_account_email = var.weather_function_sa
      audience              = var.weather_function_uri
    }
  }

  # Labels
  lifecycle {
    ignore_changes = [
      # Ignore changes to paused state (can be changed manually)
    ]
  }
}
