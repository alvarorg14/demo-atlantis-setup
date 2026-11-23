output "project_id" {
  description = "PRO project ID."
  value       = var.pro_project_id
}

output "atlantis_prod_sa_email" {
  description = "Email of the Atlantis PRO runtime GSA."
  value       = local.atlantis_prod_sa_email
}

output "terraform_pro_sa_email" {
  description = "Email of the restricted PRO Terraform execution GSA."
  value       = module.terraform_runner.email
}

output "gsa_state_pro_bucket" {
  description = "GCS bucket holding demo-atlantis-gsa PRO state."
  value       = module.gsa_state_bucket.name
}

output "atlantis_prod_vm_name" {
  description = "Name of the Atlantis PRO Compute Engine VM."
  value       = module.atlantis_vm.vm_name
}

output "atlantis_prod_public_ip" {
  description = "Public IP of the Atlantis PRO VM (point DNS here)."
  value       = module.atlantis_vm.public_ip
}

output "atlantis_prod_url" {
  description = "Expected public URL of Atlantis PRO."
  value       = local.atlantis_prod_url
}
