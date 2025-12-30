# ==============================================================================
# Cloud Build Module - dbt Automation
# ==============================================================================
# Ejecuta dbt via Cloud Build después de la ingesta de datos
# ==============================================================================

# ------------------------------------------------------------------------------
# Service Account para Cloud Build
# ------------------------------------------------------------------------------
resource "google_service_account" "cloud_build_dbt" {
  account_id   = "cloud-build-dbt"
  display_name = "Cloud Build dbt Runner"
  project      = var.project_id
}

# Permisos para Cloud Build SA
resource "google_project_iam_member" "cloud_build_bigquery" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${google_service_account.cloud_build_dbt.email}"
}

resource "google_project_iam_member" "cloud_build_storage" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.cloud_build_dbt.email}"
}

resource "google_project_iam_member" "cloud_build_logs" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloud_build_dbt.email}"
}

resource "google_project_iam_member" "cloud_build_act_as" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cloud_build_dbt.email}"
}

# ------------------------------------------------------------------------------
# Cloud Build Trigger (Manual/HTTP)
# ------------------------------------------------------------------------------
resource "google_cloudbuild_trigger" "dbt_run" {
  name        = "dbt-run-trigger"
  project     = var.project_id
  location    = var.region
  description = "Ejecuta dbt run después de la ingesta de datos"

  source_to_build {
    uri       = var.github_repo_url
    ref       = "refs/heads/main"
    repo_type = "GITHUB"
  }

  git_file_source {
    path      = "Desafio_2/dbt/cloudbuild.yaml"
    uri       = var.github_repo_url
    revision  = "refs/heads/main"
    repo_type = "GITHUB"
  }

  service_account = google_service_account.cloud_build_dbt.id

  # Permitir ejecución manual y via API
  include_build_logs = "INCLUDE_BUILD_LOGS_WITH_STATUS"
}

# ------------------------------------------------------------------------------
# Cloud Scheduler Job para disparar Cloud Build
# ------------------------------------------------------------------------------
resource "google_cloud_scheduler_job" "dbt_trigger" {
  name        = "dbt-post-ingesta"
  project     = var.project_id
  region      = var.scheduler_region
  description = "Dispara dbt run 1 hora después de la ingesta de datos"

  schedule  = var.dbt_schedule
  time_zone = var.timezone

  attempt_deadline = "600s"

  retry_config {
    retry_count          = 2
    min_backoff_duration = "30s"
    max_backoff_duration = "300s"
    max_doublings        = 2
  }

  http_target {
    http_method = "POST"
    uri         = "https://cloudbuild.googleapis.com/v1/projects/${var.project_id}/locations/${var.region}/triggers/${google_cloudbuild_trigger.dbt_run.trigger_id}:run"

    oauth_token {
      service_account_email = google_service_account.cloud_build_dbt.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }

    headers = {
      "Content-Type" = "application/json"
    }

    body = base64encode(jsonencode({
      branchName = "main"
    }))
  }

  depends_on = [google_cloudbuild_trigger.dbt_run]
}
