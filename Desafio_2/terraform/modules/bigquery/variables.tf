# ==============================================================================
# BigQuery Module - Variables
# ==============================================================================

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "location" {
  description = "BigQuery dataset location"
  type        = string
  default     = "US"
}

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "delete_contents_on_destroy" {
  description = "Whether to delete all tables when destroying datasets"
  type        = bool
  default     = false
}
