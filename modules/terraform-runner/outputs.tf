output "email" {
  description = "Email of the Terraform execution GSA."
  value       = google_service_account.runner.email
}

output "name" {
  description = "Fully qualified name of the Terraform execution GSA."
  value       = google_service_account.runner.name
}
