terraform {
  backend "gcs" {
    prefix = "demo-atlantis-setup/pro"
  }
}
