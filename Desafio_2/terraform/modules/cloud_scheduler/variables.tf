# ==============================================================================
# Cloud Scheduler Module - Variables
# ==============================================================================

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for Cloud Scheduler"
  type        = string
  default     = "europe-west1"
}

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------------------
# Weather Job Configuration
# ------------------------------------------------------------------------------
variable "weather_job_name" {
  description = "Name of the weather scheduler job"
  type        = string
  default     = "trigger-weather-ingestion"
}

variable "weather_schedule" {
  description = "Cron schedule for weather ingestion (default: daily at 3 AM Madrid time)"
  type        = string
  default     = "0 3 * * *"
}

variable "weather_timezone" {
  description = "Timezone for the weather schedule"
  type        = string
  default     = "Europe/Madrid"
}

variable "weather_function_uri" {
  description = "HTTPS URI of the weather Cloud Function"
  type        = string
}

variable "weather_function_sa" {
  description = "Service account email for invoking the weather function"
  type        = string
}

# ------------------------------------------------------------------------------
# Taxis Job Configuration
# ------------------------------------------------------------------------------
variable "taxis_job_name" {
  description = "Name of the taxis scheduler job"
  type        = string
  default     = "trigger-taxis-ingestion"
}

variable "taxis_schedule" {
  description = "Cron schedule for taxis ingestion (default: daily at 3:05 AM Madrid time, 5 min after weather)"
  type        = string
  default     = "5 3 * * *"
}

variable "taxis_timezone" {
  description = "Timezone for the taxis schedule"
  type        = string
  default     = "Europe/Madrid"
}

variable "taxis_function_uri" {
  description = "HTTPS URI of the taxis Cloud Function"
  type        = string
}

variable "taxis_function_sa" {
  description = "Service account email for invoking the taxis function"
  type        = string
}

variable "taxis_attempt_deadline" {
  description = "Deadline for taxis job attempts (duration string, e.g., '600s')"
  type        = string
  default     = "600s"
}

# ------------------------------------------------------------------------------
# Common Job Parameters
# ------------------------------------------------------------------------------
variable "attempt_deadline" {
  description = "Deadline for weather job attempts (duration string, e.g., '320s')"
  type        = string
  default     = "320s"
}

variable "retry_count" {
  description = "Number of retry attempts"
  type        = number
  default     = 3
}
