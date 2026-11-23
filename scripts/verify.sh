#!/usr/bin/env bash
#
# scripts/verify.sh
#
# Post-deployment verification of both Atlantis instances and their IAM
# boundaries. Read-only checks; safe to run repeatedly.
#
#   ./scripts/verify.sh
#
# Checks:
#   1. Both VMs running with the expected service accounts.
#   2. HTTPS endpoints answer (the /healthz proxied path).
#   3. Port 4141 NOT reachable from the internet.
#   4. Impersonation matrix: NoPRO→DEV, NoPRO→PRE, PRO→PRO only.
#   5. State bucket objectAdmin scoping.

set -euo pipefail

PRE_PROJECT="alvarorg14-demo-pre"
PRO_PROJECT="alvarorg14-demo-pro"
DEV_PROJECT="alvarorg14-demo-dev"

NONPROD_SA="atlantis-nonprod@${PRE_PROJECT}.iam.gserviceaccount.com"
PROD_SA="atlantis-prod@${PRO_PROJECT}.iam.gserviceaccount.com"
DEV_RUNNER="terraform-gsas-dev@${DEV_PROJECT}.iam.gserviceaccount.com"
PRE_RUNNER="terraform-gsas-pre@${PRE_PROJECT}.iam.gserviceaccount.com"
PRO_RUNNER="terraform-gsas-pro@${PRO_PROJECT}.iam.gserviceaccount.com"

NONPROD_URL="${NONPROD_URL:-https://atlantis-nonprod.alvarorg.com}"
PROD_URL="${PROD_URL:-https://atlantis-prod.alvarorg.com}"

pass() { printf '  \033[32mPASS\033[0m %s\n' "$*"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$*"; FAILED=1; }
head() { printf '\n== %s ==\n' "$*"; }

FAILED=0

require_gcloud() {
  command -v gcloud >/dev/null 2>&1 || { echo "gcloud not found"; exit 1; }
}

# --- 1. VMs --------------------------------------------------------------------
head "Compute Engine VMs"
for proj in "$PRE_PROJECT" "$PRO_PROJECT"; do
  status="$(gcloud compute instances list --project="$proj" \
    --filter="name~^atlantis-" --format="value(name,status)" 2>/dev/null || true)"
  if echo "$status" | grep -q "RUNNING"; then
    pass "VM running in ${proj}: ${status//$'\n'/, }"
  else
    fail "No RUNNING atlantis VM in ${proj} (got: ${status:-none})"
  fi
done

# --- 2. HTTPS endpoints ----------------------------------------------------------
head "HTTPS endpoints"
for url in "$NONPROD_URL" "$PROD_URL"; do
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$url" || echo 000)"
  if [[ "$code" == "200" || "$code" == "302" || "$code" == "401" ]]; then
    pass "${url} responds (HTTP ${code})"
  else
    fail "${url} not reachable (HTTP ${code} — check DNS/Caddy/Certificate)"
  fi
done

# --- 3. Port 4141 must NOT be public ---------------------------------------------
head "Backend port isolation (4141)"
vm_ip_pre="$(gcloud compute instances list --project="$PRE_PROJECT" \
  --filter="name~^atlantis-" --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null | head -n1 || true)"
vm_ip_pro="$(gcloud compute instances list --project="$PRO_PROJECT" \
  --filter="name~^atlantis-" --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null | head -n1 || true)"
for ip in "$vm_ip_pre" "$vm_ip_pro"; do
  [[ -n "$ip" ]] || { fail "Could not resolve VM IP"; continue; }
  if timeout 5 bash -c "</dev/tcp/${ip}/4141" 2>/dev/null; then
    fail "Port 4141 is OPEN on ${ip} — must never be publicly reachable"
  else
    pass "Port 4141 closed on ${ip}"
  fi
done

# --- 4. Impersonation matrix -------------------------------------------------------
head "Impersonation matrix (TokenCreator bindings)"
has_binding() { # $1 principal, $2 target
  gcloud iam service-accounts get-iam-policy "$2" --format="json(bindings)" 2>/dev/null \
    | grep -q "serviceAccount:${1}" && return 0 || return 1
}

if has_binding "$NONPROD_SA" "$DEV_RUNNER"; then pass "NoPRO → DEV runner"; else fail "NoPRO cannot impersonate DEV runner"; fi
if has_binding "$NONPROD_SA" "$PRE_RUNNER"; then pass "NoPRO → PRE runner"; else fail "NoPRO cannot impersonate PRE runner"; fi
if has_binding "$PROD_SA"    "$PRO_RUNNER"; then pass "PRO → PRO runner"; else fail "PRO cannot impersonate PRO runner"; fi
if has_binding "$PROD_SA"    "$DEV_RUNNER"; then fail "PRO must NOT impersonate DEV runner"; else pass "PRO ✗ DEV (correct)"; fi
if has_binding "$PROD_SA"    "$PRE_RUNNER"; then fail "PRO must NOT impersonate PRE runner"; else pass "PRO ✗ PRE (correct)"; fi
if has_binding "$NONPROD_SA" "$PRO_RUNNER"; then fail "NoPRO must NOT impersonate PRO runner"; else pass "NoPRO ✗ PRO (correct)"; fi

# --- 5. State bucket scoping ---------------------------------------------------------
head "State bucket objectAdmin scoping"
check_bucket() { # $1 project, $2 bucket, $3 expected sa
  members="$(gcloud storage buckets get-iam-policy "gs://$2" --project="$1" --format="json(bindings)" 2>/dev/null || echo '{}')"
  if echo "$members" | grep -q "serviceAccount:$3"; then
    pass "gs://$2 grants objectAdmin to $3"
  else
    fail "gs://$2 missing objectAdmin for $3"
  fi
}

check_bucket "$DEV_PROJECT" "alvarorg14-terraform-state-gsa-dev" "$DEV_RUNNER"
check_bucket "$PRE_PROJECT" "alvarorg14-terraform-state-gsa-pre" "$PRE_RUNNER"
check_bucket "$PRO_PROJECT" "alvarorg14-terraform-state-gsa-pro" "$PRO_RUNNER"

printf '\n'
if [[ "$FAILED" -eq 0 ]]; then
  echo "All verification checks passed."
else
  echo "Some checks FAILED — review the output above."
  exit 1
fi
