# ==============================================================================
# CI/CD Module - Variables
# ==============================================================================

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "service_account_id" {
  description = "ID for the GitHub Actions service account"
  type        = string
  default     = "github-actions-sa"
}

variable "create_key" {
  description = "Whether to create and export the service account key"
  type        = bool
  default     = true
}

variable "key_output_path" {
  description = "Path where to save the service account key JSON"
  type        = string
  default     = "./github-actions-key.json"
}
