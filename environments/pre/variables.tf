# Shared variables (identical defaults to ../variables.tf — Terraform does not
# inherit variables from parent directories).

variable "pre_project_id" {
  description = "GCP project ID for the PRE environment (hosts Atlantis NoPRO)."
  type        = string
  default     = "alvarorg14-demo-pre"
}

variable "bucket_location" {
  description = "GCS location (region or multi-region) for all state buckets."
  type        = string
  default     = "europe-southwest1"
}

variable "region" {
  description = "GCP region for PRE resources (network, subnet)."
  type        = string
  default     = "europe-southwest1"
}

variable "zone" {
  description = "GCP zone for the PRE Atlantis VM."
  type        = string
  default     = "europe-southwest1-b"
}

variable "atlantis_nonprod_hostname" {
  description = "Public hostname of Atlantis NoPRO. DNS configured outside Terraform."
  type        = string
  default     = "atlantis-nonprod.alvarorg.com"
}
