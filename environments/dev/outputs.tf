output "project_id" {
  description = "DEV project ID."
  value       = var.dev_project_id
}

output "terraform_dev_sa_email" {
  description = "Email of the restricted DEV Terraform execution GSA."
  value       = module.terraform_runner.email
}

output "gsa_state_dev_bucket" {
  description = "GCS bucket holding demo-atlantis-gsa DEV state."
  value       = module.gsa_state_bucket.name
}
