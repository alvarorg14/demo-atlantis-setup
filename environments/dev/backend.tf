terraform {
  # Partial backend configuration: the bucket is supplied at init time
  # (-backend-config="bucket=..."), printed by bootstrap/create-state-buckets.sh.
  backend "gcs" {
    prefix = "demo-atlantis-setup/dev"
  }
}
