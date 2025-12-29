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
  description = "Cron schedule for weather ingestion (default: daily at 6 AM Chicago time)"
  type        = string
  default     = "0 6 * * *"
}

variable "weather_timezone" {
  description = "Timezone for the schedule"
  type        = string
  default     = "America/Chicago"
}

variable "weather_function_uri" {
  description = "HTTPS URI of the weather Cloud Function"
  type        = string
}

variable "weather_function_sa" {
  description = "Service account email for invoking the function"
  type        = string
}

# ------------------------------------------------------------------------------
# Job Parameters
# ------------------------------------------------------------------------------
variable "attempt_deadline" {
  description = "Deadline for job attempts (duration string, e.g., '320s')"
  type        = string
  default     = "320s"
}

variable "retry_count" {
  description = "Number of retry attempts"
  type        = number
  default     = 3
}
