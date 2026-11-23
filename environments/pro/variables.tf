# Shared variables (identical defaults to ../variables.tf — Terraform does not
# inherit variables from parent directories).

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

variable "region" {
  description = "GCP region for PRO resources (network, subnet)."
  type        = string
  default     = "europe-southwest1"
}

variable "zone" {
  description = "GCP zone for the PRO Atlantis VM."
  type        = string
  default     = "europe-southwest1-b"
}

variable "atlantis_prod_hostname" {
  description = "Public hostname of Atlantis PRO. DNS configured outside Terraform."
  type        = string
  default     = "atlantis-prod.alvarorg.com"
}
