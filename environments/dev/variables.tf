# Shared variables (identical defaults to ../variables.tf — Terraform does not
# inherit variables from parent directories).

variable "dev_project_id" {
  description = "GCP project ID for the DEV environment."
  type        = string
  default     = "alvarorg14-demo-dev"
}

variable "bucket_location" {
  description = "GCS location (region or multi-region) for all state buckets."
  type        = string
  default     = "europe-southwest1"
}

variable "atlantis_nonprod_sa_email" {
  description = "Email of the Atlantis NoPRO runtime GSA (atlantis-nonprod@alvarorg14-demo-pre), applied in PRE."
  type        = string
}

variable "region" {
  description = "GCP region used as provider default (no regional resources in DEV)."
  type        = string
  default     = "europe-southwest1"
}
