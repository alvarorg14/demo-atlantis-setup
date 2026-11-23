# PRE environment: Atlantis NoPRO host + restricted Terraform execution GSA +
# demo-atlantis-gsa state bucket + all nonprod IAM bindings + secrets.

locals {
  atlantis_nonprod_sa_email = "atlantis-nonprod@${var.pre_project_id}.iam.gserviceaccount.com"
  terraform_pre_sa_email    = "terraform-gsas-pre@${var.pre_project_id}.iam.gserviceaccount.com"

  # Placeholder endpoints shown to the operator in outputs; DNS is configured
  # outside Terraform against the VM's ephemeral public IP.
  atlantis_nonprod_url = "https://${var.atlantis_nonprod_hostname}"
}

# --- Atlantis NoPRO runtime VM ------------------------------------------------
module "atlantis_vm" {
  source = "../../modules/atlantis-vm"

  name_prefix = "atlantis-nonprod"
  project_id  = var.pre_project_id
  env         = "nonprod"
  region      = var.region
  zone        = var.zone

  hostname = var.atlantis_nonprod_hostname
}

# --- Restricted Terraform PRE execution GSA ------------------------------------
module "terraform_runner" {
  source = "../../modules/terraform-runner"

  project_id        = var.pre_project_id
  account_id        = "terraform-gsas-pre"
  display_name      = "Terraform PRE execution (demo-atlantis-gsa)"
  environment_label = "pre"
}

# --- demo-atlantis-gsa PRE state bucket -----------------------------------------
module "gsa_state_bucket" {
  source = "../../modules/state-bucket"

  name       = "alvarorg14-terraform-state-gsa-pre"
  project_id = var.pre_project_id
  location   = var.bucket_location

  object_admin_members = ["serviceAccount:${module.terraform_runner.email}"]
}

# --- Impersonation -------------------------------------------------------------
# The Atlantis NoPRO runtime GSA may impersonate the PRE execution GSA.
# Bound directly to the target GSA, never at project level.
resource "google_service_account_iam_member" "nonprod_impersonates_pre_runner" {
  service_account_id = module.terraform_runner.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${module.atlantis_vm.runtime_sa_email}"
}

# NOTE: the NoPRO → DEV binding lives in environments/dev because the DEV GSA
# is created there. NoPRO must never impersonate PRO (enforced by the absence
# of any binding here and in environments/pro).
