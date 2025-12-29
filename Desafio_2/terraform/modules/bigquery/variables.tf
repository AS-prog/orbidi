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

# ------------------------------------------------------------------------------
# Data Transfer Variables
# ------------------------------------------------------------------------------
variable "enable_taxi_transfer" {
  description = "Enable BigQuery Data Transfer for taxi data"
  type        = bool
  default     = true
}

variable "taxi_transfer_schedule" {
  description = "Schedule for taxi data transfer (cron format)"
  type        = string
  default     = "every day 03:00"
}

variable "taxi_data_start_date" {
  description = "Start date for taxi data extraction"
  type        = string
  default     = "2023-06-01"
}

variable "taxi_data_end_date" {
  description = "End date for taxi data extraction"
  type        = string
  default     = "2023-12-31"
}

variable "taxi_row_limit" {
  description = "Maximum rows to transfer (0 for no limit)"
  type        = number
  default     = 100000
}
