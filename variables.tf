# GCP project identifiers for the demo environments.
# These are the real project IDs used throughout the setup (not placeholders).

variable "dev_project_id" {
  description = "GCP project ID for the DEV environment."
  type        = string
  default     = "alvarorg14-demo-dev"
}

variable "pre_project_id" {
  description = "GCP project ID for the PRE environment (hosts Atlantis NoPRO)."
  type        = string
  default     = "alvarorg14-demo-pre"
}

variable "pro_project_id" {
  description = "GCP project ID for the PRO environment (hosts Atlantis PRO)."
  type        = string
  default     = "alvarorg14-demo-pro"
}

variable "bucket_location" {
  description = "GCS location (region or multi-region) for all state buckets."
  type        = string
  default     = "europe-southwest1"
}
