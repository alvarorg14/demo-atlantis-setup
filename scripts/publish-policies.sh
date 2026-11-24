#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
# Publish only the exact policy and test suite recorded on the reviewed main ref.
# Fetch origin/main before running; repository branch protection supplies review.
git rev-parse --verify origin/main >/dev/null
for path in policies scripts/test-policies.sh; do
  git diff --quiet origin/main -- "$path" && git diff --cached --quiet origin/main -- "$path" || {
    echo "Policy or tests differ from origin/main; publish reviewed main only." >&2; exit 1;
  }
done
[[ -z "$(git ls-files --others --exclude-standard -- policies)" ]] || { echo 'Untracked policy files present' >&2; exit 1; }
scripts/test-policies.sh
policy="$(mktemp)"
trap 'rm -f "$policy"' EXIT
git show origin/main:policies/gsa.rego > "$policy"
for target in 'alvarorg14-demo-pre atlantis-nonprod-policy-rego' 'alvarorg14-demo-pro atlantis-prod-policy-rego'; do
  read -r project secret <<< "$target"
  echo "Publishing $secret in $project"
  gcloud secrets versions add "$secret" --project="$project" --data-file="$policy" --format='value(name)'
done
