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
    # Las siguientes APIs se habilitarán en pasos posteriores:
    # "cloudfunctions.googleapis.com",
    # "cloudscheduler.googleapis.com",
    # "pubsub.googleapis.com",
    # "storage.googleapis.com",
    # "cloudbuild.googleapis.com",
    # "run.googleapis.com",
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

# ==============================================================================
# PASO 2: Cloud Functions (Pub/Sub topics + GCS bucket)
# Descomentar cuando se complete el Paso 1
# ==============================================================================
# module "cloud_functions" {
#   source = "../../modules/cloud_functions"
#
#   project_id = var.project_id
#   region     = var.region
#   labels     = local.labels
#
#   depends_on = [google_project_service.apis]
# }

# ==============================================================================
# PASO 3: Cloud Scheduler
# Descomentar cuando se complete el Paso 2
# ==============================================================================
# module "cloud_scheduler" {
#   source = "../../modules/cloud_scheduler"
#
#   project_id      = var.project_id
#   region          = var.region
#   schedule        = var.weather_schedule
#   timezone        = "America/Chicago"
#   pubsub_topic_id = module.cloud_functions.weather_trigger_topic_id
#
#   depends_on = [
#     google_project_service.apis,
#     module.cloud_functions
#   ]
# }

# ==============================================================================
# PASO 4: IAM
# Descomentar cuando se complete el Paso 3
# ==============================================================================
# module "iam" {
#   source = "../../modules/iam"
#
#   project_id = var.project_id
#
#   depends_on = [google_project_service.apis]
# }
