# ==============================================================================
# Cloud Functions Module - Weather Ingestion Function (Gen2)
# ==============================================================================

locals {
  service_account_email = var.service_account_email != "" ? var.service_account_email : google_service_account.function_sa[0].email
  gcp_project           = var.gcp_project_env != "" ? var.gcp_project_env : var.project_id
}

# ------------------------------------------------------------------------------
# Service Account for Cloud Function
# ------------------------------------------------------------------------------
resource "google_service_account" "function_sa" {
  count = var.service_account_email == "" ? 1 : 0

  account_id   = "cloud-functions-sa"
  display_name = "Cloud Functions Service Account"
  description  = "Service account for Cloud Functions execution"
  project      = var.project_id
}

# IAM: BigQuery Data Editor
resource "google_project_iam_member" "function_bq_editor" {
  count = var.service_account_email == "" ? 1 : 0

  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.function_sa[0].email}"
}

# IAM: BigQuery Job User
resource "google_project_iam_member" "function_bq_job_user" {
  count = var.service_account_email == "" ? 1 : 0

  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.function_sa[0].email}"
}

# IAM: Storage Object Admin (para escribir Parquet a GCS)
resource "google_project_iam_member" "function_storage_admin" {
  count = var.service_account_email == "" ? 1 : 0

  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.function_sa[0].email}"
}

# ------------------------------------------------------------------------------
# GCS Bucket for Data Landing (Parquet files)
# ------------------------------------------------------------------------------
resource "google_storage_bucket" "data_landing" {
  name                        = "${var.project_id}-data-landing"
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true

  versioning {
    enabled = false
  }

  lifecycle_rule {
    condition {
      age = 90  # Retener archivos por 90 dias
    }
    action {
      type = "Delete"
    }
  }

  labels = var.labels
}

# ------------------------------------------------------------------------------
# GCS Bucket for Function Source Code
# ------------------------------------------------------------------------------
resource "google_storage_bucket" "function_source" {
  name                        = "${var.project_id}-functions-source"
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true

  versioning {
    enabled = true
  }

  labels = var.labels
}

# ------------------------------------------------------------------------------
# Zip and Upload Function Source
# ------------------------------------------------------------------------------
data "archive_file" "weather_function_source" {
  type        = "zip"
  source_dir  = var.function_source_dir
  output_path = "${path.module}/tmp/ingest_weather.zip"
}

resource "google_storage_bucket_object" "weather_function_zip" {
  name   = "ingest_weather/${data.archive_file.weather_function_source.output_md5}.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.weather_function_source.output_path
}

# ------------------------------------------------------------------------------
# Cloud Function Gen2: ingest_weather
# ------------------------------------------------------------------------------
resource "google_cloudfunctions2_function" "ingest_weather" {
  name        = var.weather_function_name
  project     = var.project_id
  location    = var.region
  description = "Ingests weather data from Open-Meteo API to BigQuery"

  build_config {
    runtime     = "python311"
    entry_point = var.weather_function_entry_point

    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.weather_function_zip.name
      }
    }
  }

  service_config {
    max_instance_count    = var.weather_function_max_instances
    min_instance_count    = 0
    available_memory      = var.weather_function_memory
    timeout_seconds       = var.weather_function_timeout
    service_account_email = local.service_account_email

    environment_variables = {
      GCP_PROJECT          = local.gcp_project
      GCS_BUCKET           = google_storage_bucket.data_landing.name
      WEATHER_START_DATE   = var.weather_start_date
      WEATHER_END_DATE     = var.weather_end_date
      OFFSET_DAYS          = var.weather_offset_days
    }
  }

  labels = var.labels

  depends_on = [
    google_project_iam_member.function_bq_editor,
    google_project_iam_member.function_bq_job_user,
    google_project_iam_member.function_storage_admin,
    google_storage_bucket.data_landing,
  ]
}

# ------------------------------------------------------------------------------
# IAM: Allow unauthenticated invocations (for testing, remove in production)
# ------------------------------------------------------------------------------
resource "google_cloud_run_service_iam_member" "invoker" {
  project  = var.project_id
  location = var.region
  service  = google_cloudfunctions2_function.ingest_weather.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ==============================================================================
# Cloud Function Gen2: ingest_taxis
# ==============================================================================

# ------------------------------------------------------------------------------
# Zip and Upload Taxis Function Source
# ------------------------------------------------------------------------------
data "archive_file" "taxis_function_source" {
  type        = "zip"
  source_dir  = var.taxis_function_source_dir
  output_path = "${path.module}/tmp/ingest_taxis.zip"
}

resource "google_storage_bucket_object" "taxis_function_zip" {
  name   = "ingest_taxis/${data.archive_file.taxis_function_source.output_md5}.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.taxis_function_source.output_path
}

# ------------------------------------------------------------------------------
# Cloud Function Gen2: ingest_taxis
# ------------------------------------------------------------------------------
resource "google_cloudfunctions2_function" "ingest_taxis" {
  name        = var.taxis_function_name
  project     = var.project_id
  location    = var.region
  description = "Ingests Chicago taxi data from BigQuery Public Dataset to GCS (daily incremental)"

  build_config {
    runtime     = "python311"
    entry_point = var.taxis_function_entry_point

    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.taxis_function_zip.name
      }
    }
  }

  service_config {
    max_instance_count    = var.taxis_function_max_instances
    min_instance_count    = 0
    available_memory      = var.taxis_function_memory
    timeout_seconds       = var.taxis_function_timeout
    service_account_email = local.service_account_email

    environment_variables = {
      GCP_PROJECT = local.gcp_project
      GCS_BUCKET  = google_storage_bucket.data_landing.name
      OFFSET_DAYS = var.taxis_offset_days
    }
  }

  labels = var.labels

  depends_on = [
    google_project_iam_member.function_bq_editor,
    google_project_iam_member.function_bq_job_user,
    google_project_iam_member.function_storage_admin,
    google_storage_bucket.data_landing,
  ]
}

# ------------------------------------------------------------------------------
# IAM: Allow unauthenticated invocations for Taxis (for testing, remove in production)
# ------------------------------------------------------------------------------
resource "google_cloud_run_service_iam_member" "taxis_invoker" {
  project  = var.project_id
  location = var.region
  service  = google_cloudfunctions2_function.ingest_taxis.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
