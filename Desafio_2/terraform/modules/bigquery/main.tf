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

# ------------------------------------------------------------------------------
# Table: raw_data.taxi_trips
# ------------------------------------------------------------------------------
resource "google_bigquery_table" "taxi_trips" {
  dataset_id          = google_bigquery_dataset.raw_data.dataset_id
  table_id            = "taxi_trips"
  project             = var.project_id
  deletion_protection = false
  description         = "Chicago taxi trips data (Jun-Dec 2023)"

  time_partitioning {
    type  = "DAY"
    field = "trip_start_timestamp"
  }

  clustering = ["pickup_community_area", "dropoff_community_area"]

  schema = <<EOF
[
  {"name": "unique_key", "type": "STRING", "mode": "NULLABLE"},
  {"name": "taxi_id", "type": "STRING", "mode": "NULLABLE"},
  {"name": "trip_start_timestamp", "type": "TIMESTAMP", "mode": "NULLABLE"},
  {"name": "trip_end_timestamp", "type": "TIMESTAMP", "mode": "NULLABLE"},
  {"name": "trip_seconds", "type": "INTEGER", "mode": "NULLABLE"},
  {"name": "trip_miles", "type": "FLOAT", "mode": "NULLABLE"},
  {"name": "pickup_census_tract", "type": "STRING", "mode": "NULLABLE"},
  {"name": "dropoff_census_tract", "type": "STRING", "mode": "NULLABLE"},
  {"name": "pickup_community_area", "type": "INTEGER", "mode": "NULLABLE"},
  {"name": "dropoff_community_area", "type": "INTEGER", "mode": "NULLABLE"},
  {"name": "fare", "type": "FLOAT", "mode": "NULLABLE"},
  {"name": "tips", "type": "FLOAT", "mode": "NULLABLE"},
  {"name": "tolls", "type": "FLOAT", "mode": "NULLABLE"},
  {"name": "extras", "type": "FLOAT", "mode": "NULLABLE"},
  {"name": "trip_total", "type": "FLOAT", "mode": "NULLABLE"},
  {"name": "payment_type", "type": "STRING", "mode": "NULLABLE"},
  {"name": "company", "type": "STRING", "mode": "NULLABLE"},
  {"name": "pickup_latitude", "type": "FLOAT", "mode": "NULLABLE"},
  {"name": "pickup_longitude", "type": "FLOAT", "mode": "NULLABLE"},
  {"name": "dropoff_latitude", "type": "FLOAT", "mode": "NULLABLE"},
  {"name": "dropoff_longitude", "type": "FLOAT", "mode": "NULLABLE"},
  {"name": "loaded_at", "type": "TIMESTAMP", "mode": "NULLABLE"}
]
EOF

  labels = var.labels
}

# ------------------------------------------------------------------------------
# Table: raw_data.weather_daily
# ------------------------------------------------------------------------------
resource "google_bigquery_table" "weather_daily" {
  dataset_id          = google_bigquery_dataset.raw_data.dataset_id
  table_id            = "weather_daily"
  project             = var.project_id
  deletion_protection = false
  description         = "Daily weather data for Chicago from Open-Meteo API"

  time_partitioning {
    type  = "DAY"
    field = "date"
  }

  schema = <<EOF
[
  {"name": "date", "type": "DATE", "mode": "REQUIRED"},
  {"name": "temperature_max", "type": "FLOAT", "mode": "NULLABLE"},
  {"name": "temperature_min", "type": "FLOAT", "mode": "NULLABLE"},
  {"name": "temperature_mean", "type": "FLOAT", "mode": "NULLABLE"},
  {"name": "precipitation_sum", "type": "FLOAT", "mode": "NULLABLE"},
  {"name": "rain_sum", "type": "FLOAT", "mode": "NULLABLE"},
  {"name": "snowfall_sum", "type": "FLOAT", "mode": "NULLABLE"},
  {"name": "wind_speed_max", "type": "FLOAT", "mode": "NULLABLE"},
  {"name": "wind_gusts_max", "type": "FLOAT", "mode": "NULLABLE"},
  {"name": "weather_code", "type": "INTEGER", "mode": "NULLABLE"},
  {"name": "loaded_at", "type": "TIMESTAMP", "mode": "NULLABLE"}
]
EOF

  labels = var.labels
}

# ------------------------------------------------------------------------------
# Table: raw_data._metadata_control (pipeline tracking)
# ------------------------------------------------------------------------------
resource "google_bigquery_table" "metadata_control" {
  dataset_id          = google_bigquery_dataset.raw_data.dataset_id
  table_id            = "_metadata_control"
  project             = var.project_id
  deletion_protection = false
  description         = "Metadata table for tracking pipeline execution"

  schema = <<EOF
[
  {"name": "pipeline_name", "type": "STRING", "mode": "REQUIRED"},
  {"name": "last_processed_date", "type": "DATE", "mode": "NULLABLE"},
  {"name": "last_run_timestamp", "type": "TIMESTAMP", "mode": "NULLABLE"},
  {"name": "status", "type": "STRING", "mode": "NULLABLE"},
  {"name": "records_processed", "type": "INTEGER", "mode": "NULLABLE"},
  {"name": "error_message", "type": "STRING", "mode": "NULLABLE"}
]
EOF

  labels = var.labels
}

# ==============================================================================
# NOTA: Data Transfer eliminado - Ahora usamos Cloud Function para ingesta
# de taxis con carga incremental diaria via Parquet -> External Table
# ==============================================================================
