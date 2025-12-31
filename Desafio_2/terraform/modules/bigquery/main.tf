# ==============================================================================
# BigQuery Module - Datasets and Tables
# ==============================================================================

# ------------------------------------------------------------------------------
# Dataset: raw_data (Bronze layer)
# ------------------------------------------------------------------------------
resource "google_bigquery_dataset" "raw_data" {
  dataset_id    = "raw_data"
  friendly_name = "Raw Data"
  description   = "Raw/Bronze layer - Landing zone for ingested data"
  location      = var.location
  project       = var.project_id

  delete_contents_on_destroy = var.delete_contents_on_destroy

  labels = var.labels
}

# ------------------------------------------------------------------------------
# Dataset: silver_data (Silver layer - Cleaned and enriched data)
# ------------------------------------------------------------------------------
resource "google_bigquery_dataset" "silver_data" {
  dataset_id    = "silver_data"
  friendly_name = "Silver Data"
  description   = "Silver layer - Cleaned, validated and enriched data"
  location      = var.location
  project       = var.project_id

  delete_contents_on_destroy = var.delete_contents_on_destroy

  labels = var.labels
}

# ------------------------------------------------------------------------------
# Dataset: analytics (Gold layer via dbt)
# ------------------------------------------------------------------------------
resource "google_bigquery_dataset" "analytics" {
  dataset_id    = "analytics"
  friendly_name = "Analytics"
  description   = "Gold/Analytics layer - Business-ready aggregations and marts"
  location      = var.location
  project       = var.project_id

  delete_contents_on_destroy = var.delete_contents_on_destroy

  labels = var.labels
}
