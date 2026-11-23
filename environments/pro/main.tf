# PRO environment: Atlantis PRO host + restricted Terraform execution GSA +
# demo-atlantis-gsa PRO state bucket + PRO impersonation binding + secrets.
# Fully independent from DEV and PRE state.

locals {
  atlantis_prod_sa_email = "atlantis-prod@${var.pro_project_id}.iam.gserviceaccount.com"
  terraform_pro_sa_email = "terraform-gsas-pro@${var.pro_project_id}.iam.gserviceaccount.com"

  atlantis_prod_url = "https://${var.atlantis_prod_hostname}"
}

# --- Atlantis PRO runtime VM ---------------------------------------------------
module "atlantis_vm" {
  source = "../../modules/atlantis-vm"

  name_prefix = "atlantis-prod"
  project_id  = var.pro_project_id
  env         = "prod"
  region      = var.region
  zone        = var.zone

  hostname = var.atlantis_prod_hostname
}

# --- Restricted Terraform PRO execution GSA -------------------------------------
module "terraform_runner" {
  source = "../../modules/terraform-runner"

  project_id        = var.pro_project_id
  account_id        = "terraform-gsas-pro"
  display_name      = "Terraform PRO execution (demo-atlantis-gsa)"
  environment_label = "pro"
}

# --- demo-atlantis-gsa PRO state bucket ------------------------------------------
module "gsa_state_bucket" {
  source = "../../modules/state-bucket"

  name       = "alvarorg14-terraform-state-gsa-pro"
  project_id = var.pro_project_id
  location   = var.bucket_location

  object_admin_members = ["serviceAccount:${module.terraform_runner.email}"]
}

# --- Impersonation -------------------------------------------------------------
# Atlantis PRO may impersonate ONLY the PRO execution GSA. No binding exists
# towards DEV or PRE (those GSAs live in other projects and receive
# TokenCreator only from the NoPRO runtime identity).
resource "google_service_account_iam_member" "prod_impersonates_pro_runner" {
  service_account_id = module.terraform_runner.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${module.atlantis_vm.runtime_sa_email}"
}
