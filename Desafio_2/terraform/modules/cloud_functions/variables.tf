# ==============================================================================
# Cloud Functions Module - Variables
# ==============================================================================

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for Cloud Functions"
  type        = string
  default     = "europe-west1"
}

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------------------
# Function Source
# ------------------------------------------------------------------------------
variable "function_source_dir" {
  description = "Local directory containing the weather function source code"
  type        = string
}

variable "taxis_function_source_dir" {
  description = "Local directory containing the taxis function source code"
  type        = string
}

# ------------------------------------------------------------------------------
# Weather Function Configuration
# ------------------------------------------------------------------------------
variable "weather_function_name" {
  description = "Name of the weather ingestion function"
  type        = string
  default     = "ingest-weather"
}

variable "weather_function_entry_point" {
  description = "Entry point for the weather function"
  type        = string
  default     = "ingest_weather"
}

variable "weather_function_memory" {
  description = "Memory allocation for the function (MB)"
  type        = string
  default     = "512M"
}

variable "weather_function_timeout" {
  description = "Timeout for the function (seconds)"
  type        = number
  default     = 300
}

variable "weather_function_max_instances" {
  description = "Maximum number of function instances"
  type        = number
  default     = 3
}

# ------------------------------------------------------------------------------
# Taxis Function Configuration
# ------------------------------------------------------------------------------
variable "taxis_function_name" {
  description = "Name of the taxis ingestion function"
  type        = string
  default     = "ingest-taxis"
}

variable "taxis_function_entry_point" {
  description = "Entry point for the taxis function"
  type        = string
  default     = "ingest_taxis"
}

variable "taxis_function_memory" {
  description = "Memory allocation for the taxis function (MB)"
  type        = string
  default     = "1Gi"
}

variable "taxis_function_timeout" {
  description = "Timeout for the taxis function (seconds)"
  type        = number
  default     = 540
}

variable "taxis_function_max_instances" {
  description = "Maximum number of taxis function instances"
  type        = number
  default     = 3
}

variable "taxis_offset_days" {
  description = "Offset days for taxis daily ingestion (e.g., 730 means process date from ~2 years ago for 2023 data)"
  type        = string
  default     = "730"
}

# ------------------------------------------------------------------------------
# Environment Variables for Weather Function
# ------------------------------------------------------------------------------
variable "gcp_project_env" {
  description = "GCP_PROJECT environment variable for the function"
  type        = string
  default     = ""
}

variable "weather_start_date" {
  description = "Start date for weather data"
  type        = string
  default     = "2023-06-01"
}

variable "weather_end_date" {
  description = "End date for weather data"
  type        = string
  default     = "2023-12-31"
}

# ------------------------------------------------------------------------------
# Service Account
# ------------------------------------------------------------------------------
variable "service_account_email" {
  description = "Service account email for the function (optional, creates one if not provided)"
  type        = string
  default     = ""
}
