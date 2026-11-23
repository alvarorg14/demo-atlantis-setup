provider "google" {
  project = var.pre_project_id
  region  = var.region

  # Applied by the operator with administrator/infrastructure-deployment
  # credentials, never with the restricted Atlantis execution GSAs.
}

provider "google-beta" {
  project = var.pre_project_id
  region  = var.region
}
