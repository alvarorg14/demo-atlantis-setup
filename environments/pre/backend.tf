terraform {
  backend "gcs" {
    prefix = "demo-atlantis-setup/pre"
  }
}
