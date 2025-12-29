# ==============================================================================
# Terraform Variables - Development Environment
# ==============================================================================

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "bigquery_location" {
  description = "BigQuery dataset location"
  type        = string
  default     = "US"
}

variable "weather_schedule" {
  description = "Cron schedule for weather ingestion (default: 2 AM daily)"
  type        = string
  default     = "0 2 * * *"
}
