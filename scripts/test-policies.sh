#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
command -v conftest >/dev/null || { echo 'conftest is required' >&2; exit 1; }
# A valid fixture also compiles the policy, so syntax errors fail before negatives.
for fixture in policies/tests/fixtures/valid-*.json; do
  conftest test --policy policies/gsa.rego "$fixture"
done
for fixture in policies/tests/fixtures/invalid-*.json policies/tests/fixtures/forbidden-*.json; do
  # JSON output distinguishes actual policy failures from execution errors.
  output="$(mktemp)"
  status=0
  conftest test --output json --policy policies/gsa.rego "$fixture" > "$output" || status=$?
  if [[ "$status" -eq 0 ]] || ! python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); assert any(x.get("failures") for x in r)' "$output"; then
    echo "Expected a policy rejection: $fixture" >&2
    rm -f "$output"
    exit 1
  fi
  rm -f "$output"
  echo "Rejected as expected: $fixture"
done
