# Reusable GCS bucket for Terraform state with the security settings required
# by this demo: versioning, uniform bucket-level access, public access
# prevention.

resource "google_storage_bucket" "this" {
  name          = var.name
  project       = var.project_id
  location      = var.location
  force_destroy = var.force_destroy

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Restrict who can read/write the state to the authorized identity (each
# Terraform execution GSA gets roles/storage.objectAdmin on its own bucket
# only). No other bindings are granted here.
resource "google_storage_bucket_iam_member" "object_admin" {
  for_each = var.object_admin_members

  bucket = google_storage_bucket.this.name
  role   = "roles/storage.objectAdmin"
  member = each.value
}
