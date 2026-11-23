output "project_id" {
  description = "PRE project ID."
  value       = var.pre_project_id
}

output "atlantis_nonprod_sa_email" {
  description = "Email of the Atlantis NoPRO runtime GSA."
  value       = local.atlantis_nonprod_sa_email
}

output "terraform_pre_sa_email" {
  description = "Email of the restricted PRE Terraform execution GSA."
  value       = module.terraform_runner.email
}

output "gsa_state_pre_bucket" {
  description = "GCS bucket holding demo-atlantis-gsa PRE state."
  value       = module.gsa_state_bucket.name
}

output "atlantis_nonprod_vm_name" {
  description = "Name of the Atlantis NoPRO Compute Engine VM."
  value       = module.atlantis_vm.vm_name
}

output "atlantis_nonprod_public_ip" {
  description = "Public IP of the Atlantis NoPRO VM (point DNS here)."
  value       = module.atlantis_vm.public_ip
}

output "atlantis_nonprod_url" {
  description = "Expected public URL of Atlantis NoPRO."
  value       = local.atlantis_nonprod_url
}
