provider "google" {
  project = var.dev_project_id
  region  = var.region

  # The operator applies this configuration with their administrator or
  # infrastructure-deployment identity — never with the restricted Atlantis
  # execution GSAs. Credentials come from gcloud ADC; nothing is stored here.
}
