# DEV environment: creates the restricted Terraform execution GSA, the
# demo-atlantis-gsa state bucket and the impersonation binding from the
# Atlantis NoPRO runtime identity. No VM here.

module "terraform_runner" {
  source = "../../modules/terraform-runner"

  project_id        = var.dev_project_id
  account_id        = "terraform-gsas-dev"
  display_name      = "Terraform DEV execution (demo-atlantis-gsa)"
  environment_label = "dev"
}

module "gsa_state_bucket" {
  source = "../../modules/state-bucket"

  name       = "alvarorg14-terraform-state-gsa-dev"
  project_id = var.dev_project_id
  location   = var.bucket_location

  object_admin_members = ["serviceAccount:${module.terraform_runner.email}"]
}

# Atlantis NoPRO (running in the PRE project) may impersonate the DEV
# execution identity. Bound directly to the target GSA, not at project level.
resource "google_service_account_iam_member" "noproworkload_impersonates_dev_runner" {
  service_account_id = module.terraform_runner.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${var.atlantis_nonprod_sa_email}"
}
