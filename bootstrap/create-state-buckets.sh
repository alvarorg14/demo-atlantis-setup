#!/usr/bin/env bash
#
# bootstrap/create-state-buckets.sh
#
# Creates the three ADMINISTRATIVE Terraform state buckets for this repository
# (demo-atlantis-setup), one per GCP project, with the required security
# settings. This is the only step that must run outside Atlantis, with an
# operator identity that has storage.admin on the three projects.
#
# The demo-atlantis-gsa state buckets are NOT created here: they are managed by
# Terraform in each environment and accessed by the restricted execution GSAs.
#
# Usage:
#   ./bootstrap/create-state-buckets.sh
#
# Overridable variables (environment):
#   BUCKET_LOCATION GCS location, region or multi-region (default: europe-southwest1)
#
# Example:
#   BUCKET_LOCATION=europe-west1 ./bootstrap/create-state-buckets.sh

set -euo pipefail

BUCKET_LOCATION="${BUCKET_LOCATION:-europe-southwest1}"

declare -A PROJECTS=(
  [dev]="alvarorg14-demo-dev"
  [pre]="alvarorg14-demo-pre"
  [pro]="alvarorg14-demo-pro"
)

log() { printf '[bootstrap] %s\n' "$*"; }

require_gcloud() {
  if ! command -v gcloud >/dev/null 2>&1; then
    log "ERROR: gcloud CLI not found in PATH."
    exit 1
  fi
}

# Idempotent bucket creation with the required security settings:
#   - object versioning
#   - uniform bucket-level access
#   - public access prevention
create_bucket() {
  local env="$1"
  local project="${PROJECTS[$env]}"
  local bucket="alvarorg14-terraform-state-${env}"

  if gsutil -p "$project" ls -b "gs://${bucket}" >/dev/null 2>&1; then
    log "Bucket gs://${bucket} already exists, skipping creation."
  else
    log "Creating gs://${bucket} in ${project} (location ${BUCKET_LOCATION})..."
    gcloud storage buckets create "gs://${bucket}" \
      --project="$project" \
      --location="$BUCKET_LOCATION" \
      --uniform-bucket-level-access \
      --public-access-prevention
  fi

  gsutil versioning set on "gs://${bucket}"
  log "Object versioning enabled on gs://${bucket}."
}

main() {
  require_gcloud

  for env in dev pre pro; do
    create_bucket "$env"
  done

  log "All administrative state buckets are ready."
  log ""
  log "Initialize each environment with a partial backend configuration, e.g.:"
  log ""
  for env in dev pre pro; do
    cat <<EOF
  cd environments/${env}
  terraform init \\
    -backend-config="bucket=alvarorg14-terraform-state-${env}" \\
    -backend-config="prefix=demo-atlantis-setup/${env}"
EOF
  done
  log ""
  log "Run Terraform with your administrator/infrastructure-deployment identity,"
  log "NOT with the restricted Atlantis execution GSAs."
}

main "$@"
