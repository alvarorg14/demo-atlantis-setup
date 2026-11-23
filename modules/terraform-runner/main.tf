# Terraform execution GSA for an environment, plus its project-scoped
# permissions. Implements the demo's least-privilege model:
#
#   - roles/iam.serviceAccountCreator on the project (create GSAs via Atlantis)
#   - roles/storage.objectAdmin on the environment's demo-atlantis-gsa state
#     bucket (granted here through the bucket member set)
#
# Explicitly NOT granted (enforced by simply not granting them here):
#   roles/owner, roles/editor, roles/iam.serviceAccountAdmin,
#   roles/resourcemanager.projectIamAdmin, project-level Storage Admin,
#   service-account key creation (roles/iam.serviceAccountKeyAdmin or the
#   iam.serviceAccountKeys.create permission).

resource "google_service_account" "runner" {
  account_id   = var.account_id
  project      = var.project_id
  display_name = var.display_name
  description  = "Restricted Terraform execution identity managed by Atlantis (${var.environment_label})."
}

resource "google_project_iam_member" "service_account_creator" {
  project = var.project_id
  role    = "roles/iam.serviceAccountCreator"
  member  = "serviceAccount:${google_service_account.runner.email}"
}
