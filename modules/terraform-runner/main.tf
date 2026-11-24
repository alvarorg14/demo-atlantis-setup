# Terraform execution GSA for an environment, plus its project-scoped
# permissions:
#
#   - roles/iam.serviceAccountAdmin on the project (manage GSAs and their IAM policies)
#   - roles/resourcemanager.projectIamAdmin on the project (manage project IAM)
#   - roles/storage.objectAdmin on the environment's demo-atlantis-gsa state
#     bucket (granted by the state-bucket module)
#
# Not granted by this module (individual environments may add permissions):
#   roles/owner, roles/editor,
#   project-level Storage Admin,
#   service-account key creation (roles/iam.serviceAccountKeyAdmin or the
#   iam.serviceAccountKeys.create permission).

resource "google_service_account" "runner" {
  account_id   = var.account_id
  project      = var.project_id
  display_name = var.display_name
  description  = "Restricted Terraform execution identity managed by Atlantis (${var.environment_label})."
}

moved {
  from = google_project_iam_member.service_account_creator
  to   = google_project_iam_member.service_account_admin
}

resource "google_project_iam_member" "service_account_admin" {
  project = var.project_id
  role    = "roles/iam.serviceAccountAdmin"
  member  = "serviceAccount:${google_service_account.runner.email}"
}

resource "google_project_iam_member" "project_iam_admin" {
  project = var.project_id
  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${google_service_account.runner.email}"
}
