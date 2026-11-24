#!/usr/bin/env bash
# Read-only verification over IAP SSH; set ZONE if the VMs use another zone.
set -euo pipefail
zone="${ZONE:-europe-southwest1-b}"
for target in 'alvarorg14-demo-pre atlantis-nonprod atlantis-nonprod-policy-rego' 'alvarorg14-demo-pro atlantis-prod atlantis-prod-policy-rego'; do
  read -r project instance secret <<< "$target"
  echo "Checking $instance in $project"
  gcloud secrets describe "$secret" --project="$project" >/dev/null
  gcloud secrets versions describe latest --secret="$secret" --project="$project" --format='value(state)' | grep -Fx ENABLED >/dev/null
  gcloud compute ssh "$instance-vm" --project="$project" --zone="$zone" --tunnel-through-iap --command="sudo bash -s -- '$instance'" <<'REMOTE'
set -euo pipefail
container="$1"
mountpoint -q /etc/atlantis
[[ "$(readlink -f "$(findmnt -n -o SOURCE --target /etc/atlantis)")" == "$(readlink -f /dev/disk/by-id/google-atlantis-data)" ]]
sudo docker exec "$container" sh -c "grep -Eq '^[[:space:]]*policy_check:[[:space:]]*true' /etc/atlantis/repos.yaml && grep -Fq 'path: /etc/atlantis/policies' /etc/atlantis/repos.yaml"
sudo docker inspect "$container" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -Fx 'ATLANTIS_ENABLE_POLICY_CHECKS=true'
sudo docker inspect "$container" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -Fx 'ATLANTIS_DATA_DIR=/atlantis-data'
sudo docker inspect "$container" --format '{{range .Mounts}}{{println .Source .Destination .RW}}{{end}}' | grep -Fx '/opt/atlantis/policies /etc/atlantis/policies false'
sudo docker inspect "$container" --format '{{range .Mounts}}{{println .Source .Destination .RW}}{{end}}' | grep -Fx '/etc/atlantis /atlantis-data true'
sudo docker exec "$container" sh -c 'test -s /etc/atlantis/policies/gsa.rego && test ! -w /etc/atlantis/policies/gsa.rego && test -w /atlantis-data && conftest --version && printf "{\"resource_changes\":[]}" | conftest test --policy /etc/atlantis/policies/gsa.rego - && wget -q -O /dev/null http://127.0.0.1:4141/healthz'
[[ "$(sudo docker inspect "$container" --format '{{.State.Health.Status}}')" == healthy ]]
REMOTE
done
echo 'Both policy configurations passed verification.'
