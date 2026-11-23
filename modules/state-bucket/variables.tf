variable "name" {
  description = "Globally unique GCS bucket name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9._-]{1,98}[a-z0-9]$", var.name))
    error_message = "Bucket name must be 3-100 lowercase letters, digits, dots, hyphens or underscores."
  }
}

variable "project_id" {
  description = "Project that owns the bucket."
  type        = string
}

variable "location" {
  description = "GCS location (region or multi-region)."
  type        = string
  default     = "europe-southwest1"
}

variable "force_destroy" {
  description = "Whether the bucket can be deleted with objects inside. Keep false for state buckets."
  type        = bool
  default     = false
}

# Set of IAM members (e.g. "serviceAccount:terraform-gsas-dev@...") granted
# roles/storage.objectAdmin on this bucket only. Empty by default so that
# administrative buckets (accessed by the operator identity) grant nothing
# extra.
variable "object_admin_members" {
  description = "IAM members granted roles/storage.objectAdmin on the bucket."
  type        = set(string)
  default     = []
}
