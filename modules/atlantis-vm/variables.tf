variable "name_prefix" {
  description = "Prefix for all resources of this Atlantis instance (e.g. atlantis-nonprod)."
  type        = string
}

variable "project_id" {
  description = "Project hosting this Atlantis VM."
  type        = string
}

variable "env" {
  description = "Environment label used in tags, secret names and metadata (nonprod/prod)."
  type        = string

  validation {
    condition     = contains(["nonprod", "prod"], var.env)
    error_message = "env must be either 'nonprod' or 'prod'."
  }
}

variable "region" {
  description = "Region for the network and subnet."
  type        = string
}

variable "zone" {
  description = "Zone for the VM and data disk."
  type        = string
}

variable "machine_type" {
  description = "Compute Engine machine type."
  type        = string
  default     = "e2-small"
}

variable "boot_image" {
  description = "Boot disk image (Debian)."
  type        = string
  default     = "debian-cloud/debian-13"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB."
  type        = number
  default     = 30
}

variable "subnet_cidr" {
  description = "CIDR range of the dedicated subnet."
  type        = string
  default     = "10.10.0.0/28"
}

variable "hostname" {
  description = "Public hostname where this Atlantis instance will be reachable (informational; DNS is configured outside Terraform)."
  type        = string
}

variable "enable_oslogin" {
  description = "Grant the VM GSA roles/compute.osLogin. OS Login must be enabled project-wide."
  type        = bool
  default     = true
}
