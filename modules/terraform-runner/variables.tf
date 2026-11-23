variable "project_id" {
  description = "Project the execution GSA belongs to and operates on."
  type        = string
}

variable "account_id" {
  description = "Service-account account_id (the part before @)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}$", var.account_id))
    error_message = "account_id must start with a letter, contain only lowercase letters, digits and hyphens, and be 6-30 characters."
  }
}

variable "display_name" {
  description = "Display name for the execution GSA."
  type        = string
}

variable "environment_label" {
  description = "Human-readable environment label used in the SA description (dev/pre/pro)."
  type        = string
}
