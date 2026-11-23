output "vm_name" {
  description = "Name of the Atlantis VM."
  value       = google_compute_instance.this.name
}

output "vm_self_link" {
  description = "Self link of the Atlantis VM."
  value       = google_compute_instance.this.self_link
}

output "public_ip" {
  description = "External IP of the Atlantis VM (point DNS here)."
  value       = google_compute_instance.this.network_interface[0].access_config[0].nat_ip
}

output "runtime_sa_email" {
  description = "Email of the dedicated Atlantis runtime service account."
  value       = google_service_account.runtime.email
}

output "secret_names" {
  description = "Secret Manager secret IDs this instance reads at startup."
  value = concat(
    keys(google_secret_manager_secret.config),
    keys(google_secret_manager_secret.github),
  )
}

output "hostname" {
  description = "Configured public hostname for this instance."
  value       = var.hostname
}
