#!/usr/bin/env bash
#
# scripts/deploy.sh
#
# Convenience wrapper that runs the full deployment sequence documented in
# the README. Terraform is ALWAYS invoked with explicit user intent:
#
#   ./scripts/deploy.sh bootstrap              # create admin state buckets
#   ./scripts/deploy.sh init <pre|dev|pro>     # terraform init (asks for bucket)
#   ./scripts/deploy.sh plan <pre|dev|pro> [extra terraform args]
#   ./scripts/deploy.sh apply <pre|dev|pro> [extra terraform args]
#
# Order matters: pre creates the NoPRO runtime SA needed by dev; pro is
# independent but runs last per the documented sequence.
#
# The operator must be authenticated (gcloud auth application-default login)
# with an administrator / infrastructure-deployment identity.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BUCKET_LOCATION="${BUCKET_LOCATION:-europe-southwest1}"

usage() {
  sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 1
}

bucket_for() {
  case "$1" in
    pre) echo "alvarorg14-terraform-state-pre" ;;
    dev) echo "alvarorg14-terraform-state-dev" ;;
    pro) echo "alvarorg14-terraform-state-pro" ;;
    *)   return 1 ;;
  esac
}

cmd="${1:-}"
env="${2:-}"

case "$cmd" in
  bootstrap)
    (cd "${REPO_ROOT}/bootstrap" && \
      BUCKET_LOCATION="$BUCKET_LOCATION" \
      ./create-state-buckets.sh)
    ;;

  init|plan|apply)
    [[ -n "$env" ]] || usage
    shift 2
    bucket="$(bucket_for "$env")"
    cd "${REPO_ROOT}/environments/$env"

    case "$cmd" in
      init)
        terraform init \
          -backend-config="bucket=${bucket}" \
          -backend-config="prefix=demo-atlantis-setup/${env}"
        ;;
      plan)
        terraform plan "$@"
        ;;
      apply)
        terraform apply "$@"
        ;;
    esac
    ;;

  *)
    usage
    ;;
esac
