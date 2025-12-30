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

# ==============================================================================
# Data Security Variables
# ==============================================================================

variable "payment_data_readers" {
  description = "List of IAM members who can read payment_type column (e.g., user:email@example.com, group:analysts@company.com)"
  type        = list(string)
  default     = []
}

variable "bigquery_data_viewers" {
  description = "List of IAM members who can query BigQuery but NOT protected columns (e.g., user:email@example.com)"
  type        = list(string)
  default     = []
}

variable "enable_payment_masking" {
  description = "Enable data masking for payment_type column (users without access see masked values)"
  type        = bool
  default     = false
}

# ==============================================================================
# CI/CD Variables
# ==============================================================================

variable "create_github_actions_key" {
  description = "Whether to create and export the GitHub Actions service account key"
  type        = bool
  default     = true
}

# ==============================================================================
# Cloud Build / dbt Automation Variables
# ==============================================================================

variable "github_repo_url" {
  description = "URL del repositorio GitHub para Cloud Build"
  type        = string
  default     = "https://github.com/AS-prog/orbidi"
}

variable "dbt_schedule" {
  description = "Cron schedule para dbt (después de ingesta). Default: 4:00 AM (1h después de taxis)"
  type        = string
  default     = "0 4 * * *"
}
