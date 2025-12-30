# ==============================================================================
# Terraform Configuration - Development Environment
# ==============================================================================
# Orbidi Technical Challenge - Chicago Taxi & Weather Analysis
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Uncomment to use GCS backend for state
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "orbidi-challenge/dev"
  # }
}

# ------------------------------------------------------------------------------
# Provider Configuration
# ------------------------------------------------------------------------------
provider "google" {
  project = var.project_id
  region  = var.region
}

# ------------------------------------------------------------------------------
# Local Variables
# ------------------------------------------------------------------------------
locals {
  labels = {
    environment = "dev"
    project     = "orbidi-challenge"
    managed_by  = "terraform"
  }
}

# ------------------------------------------------------------------------------
# Enable Required APIs
# ------------------------------------------------------------------------------
resource "google_project_service" "apis" {
  for_each = toset([
    "bigquery.googleapis.com",
    "bigquerydatatransfer.googleapis.com",
    "iam.googleapis.com",
    # Cloud Functions y dependencias
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "run.googleapis.com",
    "storage.googleapis.com",
    "artifactregistry.googleapis.com",
    # Cloud Scheduler
    "cloudscheduler.googleapis.com",
    # Data Catalog (Column-Level Security)
    "datacatalog.googleapis.com",
    "bigquerydatapolicy.googleapis.com",
  ])

  project                    = var.project_id
  service                    = each.key
  disable_on_destroy         = false
  disable_dependent_services = false
}

# ------------------------------------------------------------------------------
# Module: BigQuery (Paso 1 - Capa Raw)
# ------------------------------------------------------------------------------
module "bigquery" {
  source = "../../modules/bigquery"

  project_id                 = var.project_id
  location                   = var.bigquery_location
  labels                     = local.labels
  delete_contents_on_destroy = true

  depends_on = [google_project_service.apis]
}

# ------------------------------------------------------------------------------
# Module: Cloud Functions (Weather & Taxis Ingestion)
# ------------------------------------------------------------------------------
module "cloud_functions" {
  source = "../../modules/cloud_functions"

  project_id          = var.project_id
  region              = var.region
  labels              = local.labels
  function_source_dir = "${path.module}/../../../src/ingest_weather"

  # Weather function configuration
  weather_function_name    = "ingest-weather"
  weather_function_memory  = "512M"
  weather_function_timeout = 300

  # Environment variables for weather
  weather_start_date = "2023-06-01"
  weather_end_date   = "2023-12-31"

  # Taxis function configuration
  taxis_function_source_dir = "${path.module}/../../../src/ingest_taxis"
  taxis_function_name       = "ingest-taxis"
  taxis_function_memory     = "1Gi"
  taxis_function_timeout    = 540
  taxis_offset_days         = "730"  # 2025-12-29 - 730 = 2023-12-29

  depends_on = [
    google_project_service.apis,
    module.bigquery
  ]
}

# ------------------------------------------------------------------------------
# BigQuery External Table: weather_daily (reads from Parquet in GCS with Hive partitioning)
# ------------------------------------------------------------------------------
resource "google_bigquery_table" "weather_external" {
  dataset_id          = module.bigquery.raw_data_dataset_id
  table_id            = "weather_daily_ext"
  project             = var.project_id
  deletion_protection = false
  description         = "External table reading weather data from Parquet with Hive-style daily partitioning"

  external_data_configuration {
    autodetect    = true
    source_format = "PARQUET"
    source_uris   = ["gs://${module.cloud_functions.data_landing_bucket}/weather/*"]

    hive_partitioning_options {
      mode                     = "AUTO"
      source_uri_prefix        = "gs://${module.cloud_functions.data_landing_bucket}/weather/"
      require_partition_filter = false
    }
  }

  labels = local.labels

  depends_on = [module.cloud_functions]
}

# ------------------------------------------------------------------------------
# BigQuery External Table: taxi_trips (reads from Parquet in GCS with Hive partitioning)
# ------------------------------------------------------------------------------
resource "google_bigquery_table" "taxis_external" {
  dataset_id          = module.bigquery.raw_data_dataset_id
  table_id            = "taxi_trips_ext"
  project             = var.project_id
  deletion_protection = false
  description         = "External table reading taxi trips data from Parquet with Hive-style daily partitioning"

  # Schema explícito para evitar errores de autodetect con tipos STRING/INT
  schema = jsonencode([
    { name = "unique_key", type = "STRING", mode = "NULLABLE" },
    { name = "taxi_id", type = "STRING", mode = "NULLABLE" },
    { name = "trip_start_timestamp", type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "trip_end_timestamp", type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "trip_seconds", type = "INTEGER", mode = "NULLABLE" },
    { name = "trip_miles", type = "FLOAT", mode = "NULLABLE" },
    { name = "pickup_community_area", type = "INTEGER", mode = "NULLABLE" },
    { name = "dropoff_community_area", type = "INTEGER", mode = "NULLABLE" },
    { name = "fare", type = "FLOAT", mode = "NULLABLE" },
    { name = "tips", type = "FLOAT", mode = "NULLABLE" },
    { name = "tolls", type = "FLOAT", mode = "NULLABLE" },
    { name = "extras", type = "FLOAT", mode = "NULLABLE" },
    { name = "trip_total", type = "FLOAT", mode = "NULLABLE" },
    { name = "payment_type", type = "STRING", mode = "NULLABLE" },
    { name = "company", type = "STRING", mode = "NULLABLE" },
    { name = "pickup_latitude", type = "FLOAT", mode = "NULLABLE" },
    { name = "pickup_longitude", type = "FLOAT", mode = "NULLABLE" },
    { name = "dropoff_latitude", type = "FLOAT", mode = "NULLABLE" },
    { name = "dropoff_longitude", type = "FLOAT", mode = "NULLABLE" },
    { name = "loaded_at", type = "TIMESTAMP", mode = "NULLABLE" }
  ])

  external_data_configuration {
    autodetect    = false
    source_format = "PARQUET"
    source_uris   = ["gs://${module.cloud_functions.data_landing_bucket}/taxis/*"]

    hive_partitioning_options {
      mode                     = "AUTO"
      source_uri_prefix        = "gs://${module.cloud_functions.data_landing_bucket}/taxis/"
      require_partition_filter = false
    }
  }

  labels = local.labels

  depends_on = [module.cloud_functions]
}

# ==============================================================================
# Module: Cloud Scheduler (Weather & Taxis Ingestion Daily)
# ==============================================================================
module "cloud_scheduler" {
  source = "../../modules/cloud_scheduler"

  project_id = var.project_id
  region     = var.region

  # Weather job configuration
  weather_job_name     = "trigger-weather-ingestion"
  weather_schedule     = "0 3 * * *"  # Daily at 3:00 AM Madrid time
  weather_timezone     = "Europe/Madrid"
  weather_function_uri = module.cloud_functions.function_uri
  weather_function_sa  = module.cloud_functions.function_service_account

  # Taxis job configuration
  taxis_job_name     = "trigger-taxis-ingestion"
  taxis_schedule     = "5 3 * * *"  # Daily at 3:05 AM Madrid time (5 min after weather)
  taxis_timezone     = "Europe/Madrid"
  taxis_function_uri = module.cloud_functions.taxis_function_uri
  taxis_function_sa  = module.cloud_functions.function_service_account

  depends_on = [
    google_project_service.apis,
    module.cloud_functions
  ]
}

# ==============================================================================
# Module: Data Security (Column-Level Security)
# ==============================================================================
module "data_security" {
  source = "../../modules/data_security"

  project_id        = var.project_id
  region            = var.region
  bigquery_location = var.bigquery_location
  taxonomy_name     = "orbidi_sensitive_data"

  # Usuarios/grupos que pueden ver la columna payment_type
  # Formato: user:email@example.com, group:group@example.com, serviceAccount:sa@project.iam.gserviceaccount.com
  payment_data_readers = var.payment_data_readers

  # Habilitar enmascaramiento de datos (opcional)
  enable_data_masking = var.enable_payment_masking

  depends_on = [google_project_service.apis]
}

# ------------------------------------------------------------------------------
# NOTA: Policy Tag para payment_type en analytics.taxis_weather_enriched
# ------------------------------------------------------------------------------
# La tabla es creada por dbt, por lo que el policy tag debe aplicarse después
# de cada ejecución de dbt run. Usar el script:
#   scripts/apply_policy_tags.sh
#
# O ejecutar manualmente:
#   POLICY_TAG=$(terraform output -raw payment_policy_tag)
#   bq show --format=prettyjson --schema PROJECT:analytics.taxis_weather_enriched > /tmp/schema.json
#   # Modificar schema.json para agregar policyTags a payment_type
#   bq update PROJECT:analytics.taxis_weather_enriched /tmp/schema.json
# ------------------------------------------------------------------------------

# ==============================================================================
# PASO 4: IAM (Legacy - Usar data_security module en su lugar)
# ==============================================================================
# module "iam" {
#   source = "../../modules/iam"
#
#   project_id = var.project_id
#
#   depends_on = [google_project_service.apis]
# }
