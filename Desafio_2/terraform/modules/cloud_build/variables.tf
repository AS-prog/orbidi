# ==============================================================================
# Cloud Build Module - Variables
# ==============================================================================

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "Region para Cloud Build triggers"
  type        = string
  default     = "europe-west1"
}

variable "scheduler_region" {
  description = "Region para Cloud Scheduler (puede diferir de Cloud Build)"
  type        = string
  default     = "europe-west1"
}

variable "github_repo_url" {
  description = "URL del repositorio GitHub"
  type        = string
}

variable "github_connection_name" {
  description = "Nombre de la conexión GitHub en Cloud Build"
  type        = string
  default     = "github-connection"
}

variable "github_repository_name" {
  description = "Nombre del repositorio vinculado en Cloud Build"
  type        = string
  default     = "orbidi-repo"
}

variable "dbt_schedule" {
  description = "Cron schedule para dbt (después de ingesta)"
  type        = string
  default     = "0 3 * * *"  # 3:00 AM (1 hora después de ingesta a las 2:00 AM)
}

variable "timezone" {
  description = "Timezone para el schedule"
  type        = string
  default     = "Europe/Madrid"
}
