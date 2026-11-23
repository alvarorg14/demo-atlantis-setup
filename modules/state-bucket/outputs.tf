output "name" {
  description = "Name of the created state bucket."
  value       = google_storage_bucket.this.name
}

output "url" {
  description = "gs:// URL of the created state bucket."
  value       = google_storage_bucket.this.url
}
