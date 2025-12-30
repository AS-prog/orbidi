# ==============================================================================
# Data Security Module - Variables
# ==============================================================================

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "Region for Data Catalog resources"
  type        = string
  default     = "europe-west1"
}

variable "bigquery_location" {
  description = "BigQuery dataset location (for data policies)"
  type        = string
  default     = "EU"
}

variable "taxonomy_name" {
  description = "Display name for the taxonomy"
  type        = string
  default     = "sensitive_data_taxonomy"
}

variable "payment_data_readers" {
  description = "List of IAM members who can read payment data (e.g., user:email@example.com, group:group@example.com, serviceAccount:sa@project.iam.gserviceaccount.com)"
  type        = list(string)
  default     = []
}

variable "enable_data_masking" {
  description = "Enable data masking policy for payment_type column"
  type        = bool
  default     = false
}
