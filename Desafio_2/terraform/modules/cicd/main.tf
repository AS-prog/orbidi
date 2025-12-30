# ==============================================================================
# CI/CD Module - Service Account for GitHub Actions
# ==============================================================================

# ------------------------------------------------------------------------------
# Service Account para GitHub Actions
# ------------------------------------------------------------------------------
resource "google_service_account" "github_actions" {
  account_id   = var.service_account_id
  display_name = "GitHub Actions CI/CD"
  description  = "Service account for GitHub Actions workflows (dbt, terraform validation)"
  project      = var.project_id
}

# ------------------------------------------------------------------------------
# IAM Roles para la Service Account
# ------------------------------------------------------------------------------

# BigQuery Admin - para ejecutar dbt
resource "google_project_iam_member" "bigquery_admin" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# Storage Admin - para acceder a GCS (external tables)
resource "google_project_iam_member" "storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# Data Catalog Fine Grained Reader - para acceder a columnas protegidas
resource "google_project_iam_member" "datacatalog_reader" {
  project = var.project_id
  role    = "roles/datacatalog.categoryFineGrainedReader"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# ------------------------------------------------------------------------------
# Key JSON para GitHub Secret (opcional - se puede crear manualmente)
# ------------------------------------------------------------------------------
resource "google_service_account_key" "github_actions_key" {
  count              = var.create_key ? 1 : 0
  service_account_id = google_service_account.github_actions.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

# ------------------------------------------------------------------------------
# Guardar key en archivo local (solo si create_key = true)
# ------------------------------------------------------------------------------
resource "local_file" "github_actions_key" {
  count           = var.create_key ? 1 : 0
  content         = base64decode(google_service_account_key.github_actions_key[0].private_key)
  filename        = var.key_output_path
  file_permission = "0600"
}
