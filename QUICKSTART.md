# Quickstart — deploy Atlantis end to end

Step-by-step guide to go from a clean checkout to two working Atlantis
instances. Follow the steps **in order**; later steps depend on earlier ones.

Estimated time: ~1 hour (plus DNS propagation and one reboot).

---

## Step 0 — Prerequisites

| Requirement | Check |
|---|---|
| `gcloud` CLI installed and authenticated | `gcloud auth login && gcloud auth application-default login` |
| Terraform `1.17.2` | `terraform version` (use [tfenv](https://github.com/tfutils/tfenv): `tfenv install`) |
| `jq`, `curl`, `openssl` | `command -v jq curl openssl` |
| Three GCP projects with billing | `gcloud projects describe alvarorg14-demo-dev` (and `-pre`, `-pro`) |
| DNS control of `alvarorg.com` | you will add two A records in step 6 |
| GitHub org/user admin | to create two GitHub Apps in step 7 |

Your identity needs, **in all three projects**: service account + IAM admin,
storage admin, Compute admin, Secret Manager admin, and (pre/pro) network
admin. For a one-off demo the `roles/editor` primitive on the three projects
covers all of it — the *demo identities themselves* never get these roles
(that's the whole point of the setup).

```bash
# Set your operator identity once; gcloud picks it up for everything below.
gcloud config set account <your-admin@example.com>
```

Enable the APIs used by the VMs, service account impersonation, and GSA
creation (API activation can take a few minutes to propagate):

```bash
gcloud services enable iam.googleapis.com iamcredentials.googleapis.com --project=alvarorg14-demo-dev
gcloud services enable compute.googleapis.com secretmanager.googleapis.com iam.googleapis.com iamcredentials.googleapis.com --project=alvarorg14-demo-pre
gcloud services enable compute.googleapis.com secretmanager.googleapis.com iam.googleapis.com iamcredentials.googleapis.com --project=alvarorg14-demo-pro
```

Bucket names are fixed (`alvarorg14-terraform-state-{dev,pre,pro}` and
`alvarorg14-terraform-state-gsa-{dev,pre,pro}`) — nothing to choose here.

---

## Step 1 — Bootstrap administrative state buckets

Creates `alvarorg14-terraform-state-{dev,pre,pro}` with versioning, UBLA
and public access prevention.

```bash
cd bootstrap
BUCKET_LOCATION=europe-southwest1 ./create-state-buckets.sh
cd ..
```

✅ Check: the script prints the three bucket names and the `terraform init`
commands. No errors.

---

## Step 2 — Deploy PRE (hosts Atlantis NoPRO)

```bash
./scripts/deploy.sh init pre     # uses bucket alvarorg14-terraform-state-pre
./scripts/deploy.sh plan pre     # REVIEW the plan: VM, network, secrets, runner SA
./scripts/deploy.sh apply pre
```

This creates: `atlantis-nonprod` VM + runtime GSA, `terraform-gsas-pre`
runner, `alvarorg14-terraform-state-gsa-pre` bucket, NoPRO→PRE TokenCreator,
7 Secret Manager secrets, network + firewall rules.

✅ Check:

```bash
cd environments/pre && terraform output && cd ../..
# Note atlantis_nonprod_public_ip and atlantis_nonprod_sa_email
```

Wait ~3–5 minutes after apply: the VM boots, installs Docker, pulls secrets
and starts the containers. (It will fail the compose step until steps 5 and 7 fill
the secrets — that's expected.)

---

## Step 3 — Deploy DEV

```bash
./scripts/deploy.sh init dev
ATLANTIS_NONPROD_SA_EMAIL="$(cd environments/pre && terraform output -raw atlantis_nonprod_sa_email)"
./scripts/deploy.sh plan dev -var="atlantis_nonprod_sa_email=$ATLANTIS_NONPROD_SA_EMAIL"
./scripts/deploy.sh apply dev -var="atlantis_nonprod_sa_email=$ATLANTIS_NONPROD_SA_EMAIL"
```

`scripts/deploy.sh` passes any extra arguments after the subcommand straight
to Terraform, so `-var=...` works on `plan`/`apply` too if you prefer that
over the explicit plan file above.

This creates: `terraform-gsas-dev` runner, `alvarorg14-terraform-state-gsa-dev`
bucket, NoPRO→DEV TokenCreator.

✅ Check:

```bash
cd environments/dev && terraform output && cd ../..
```

---

## Step 4 — Deploy PRO (hosts Atlantis PRO)

```bash
./scripts/deploy.sh init pro
./scripts/deploy.sh plan pro
./scripts/deploy.sh apply pro
```

✅ Check: `cd environments/pro && terraform output && cd ../..` — note
`atlantis_prod_public_ip` and `atlantis_prod_sa_email`.

---

## Step 5 — Push deployment files and GitHub credentials to Secret Manager

The VMs poll these secrets on boot; they are NOT in Terraform.

If you applied an earlier revision, run and review `./scripts/deploy.sh plan pre`
and `./scripts/deploy.sh plan pro`, then apply both before continuing. The plans
remove the obsolete `gh-user` and `gh-token` secrets and their versions, update
the startup script, and open port 80 for certificate validation. Export anything
you need from the old secrets before applying. Upload the updated Compose files
below before restarting the VMs.

### 5a. Edit the env files

```bash
cp deployments/nonprod/.env.example /tmp/nonprod.env
cp deployments/prod/.env.example   /tmp/prod.env
# Edit both: set your GitHub org/user in ATLANTIS_REPO_ALLOWLIST
# (alvarorg14 by default). Hostnames are already correct (alvarorg.com).
```

Keep `ATLANTIS_WRITE_GIT_CREDS=true` in both files. Atlantis requires it
to clone repositories using the GitHub App installation credentials.
Keep `ATLANTIS_HIDE_PREV_PLAN_COMMENTS=true` and set
`ATLANTIS_GH_APP_SLUG` to the corresponding GitHub App's slug to collapse
previous plan-result comments when a new plan is posted.

### 5b. Push config files

```bash
# NoPRO
gcloud secrets versions add atlantis-nonprod-env-file   --project=alvarorg14-demo-pre --data-file=/tmp/nonprod.env
gcloud secrets versions add atlantis-nonprod-compose    --project=alvarorg14-demo-pre --data-file=deployments/nonprod/compose.yaml
gcloud secrets versions add atlantis-nonprod-repos-yaml --project=alvarorg14-demo-pre --data-file=deployments/nonprod/repos.yaml
gcloud secrets versions add atlantis-nonprod-caddyfile  --project=alvarorg14-demo-pre --data-file=deployments/nonprod/Caddyfile

# PRO
gcloud secrets versions add atlantis-prod-env-file      --project=alvarorg14-demo-pro --data-file=/tmp/prod.env
gcloud secrets versions add atlantis-prod-compose       --project=alvarorg14-demo-pro --data-file=deployments/prod/compose.yaml
gcloud secrets versions add atlantis-prod-repos-yaml    --project=alvarorg14-demo-pro --data-file=deployments/prod/repos.yaml
gcloud secrets versions add atlantis-prod-caddyfile     --project=alvarorg14-demo-pro --data-file=deployments/prod/Caddyfile
```

✅ Check: `gcloud secrets list --project=alvarorg14-demo-pre` shows 7 secrets
(4 config + 3 GitHub App secrets).

### 5c. Generate webhook secrets

Keep these files for the GitHub App setup in step 7:

```bash
openssl rand -hex 32 > /tmp/noprod-webhook-secret.txt
openssl rand -hex 32 > /tmp/prod-webhook-secret.txt
chmod 600 /tmp/noprod-webhook-secret.txt /tmp/prod-webhook-secret.txt

gcloud secrets versions add atlantis-nonprod-gh-webhook-secret --project=alvarorg14-demo-pre --data-file=/tmp/noprod-webhook-secret.txt
gcloud secrets versions add atlantis-prod-gh-webhook-secret --project=alvarorg14-demo-pro --data-file=/tmp/prod-webhook-secret.txt
```

## Step 6 — DNS

Create A records pointing at the VM public IPs:

```text
atlantis-nonprod.alvarorg.com  ->  <atlantis_nonprod_public_ip>
atlantis-prod.alvarorg.com     ->  <atlantis_prod_public_ip>
```

For Cloudflare, use DNS only (grey cloud) initially. These IPs are ephemeral:
check the records after stopping and starting a VM. Caddy obtains certificates
when the stack starts; ports 80 and 443 must be reachable.

## Step 7 — Create and install the two GitHub Apps

Create each App under Settings → Developer settings → GitHub Apps → **New GitHub App**:

| Setting | `demo-atlantis-nonprod` | `demo-atlantis-prod` |
|---|---|---|
| Homepage URL | `https://atlantis-nonprod.alvarorg.com` | `https://atlantis-prod.alvarorg.com` |
| Webhook URL | `https://atlantis-nonprod.alvarorg.com/events` | `https://atlantis-prod.alvarorg.com/events` |
| Webhook secret | content of `/tmp/noprod-webhook-secret.txt` | content of `/tmp/prod-webhook-secret.txt` |
| SSL verification | enabled | enabled |
| Permissions | Repository: Administration (r), Contents (r), Pull requests (rw), Commit statuses (rw), Issues (rw) | same |
| Subscribe to | Pull request, Issue comment, Push | same |

Install each App on `demo-atlantis-gsa` only. Upload the App IDs and replace
the key path placeholders with the locations of your downloaded PEM files:

```bash
printf '%s' '5894812' | gcloud secrets versions add atlantis-nonprod-gh-app-id --project=alvarorg14-demo-pre --data-file=-
gcloud secrets versions add atlantis-nonprod-gh-app-key --project=alvarorg14-demo-pre --data-file=/path/to/nonprod-app.pem

printf '%s' '5894912' | gcloud secrets versions add atlantis-prod-gh-app-id --project=alvarorg14-demo-pro --data-file=-
gcloud secrets versions add atlantis-prod-gh-app-key --project=alvarorg14-demo-pro --data-file=/path/to/prod-app.pem
```

The Apps authenticate Atlantis; no GitHub username or personal access token is required.

## Step 8 — Restart the VMs

After all seven secrets per environment have versions, restart both VMs so the
startup script fetches the configuration and App credentials:

```bash
gcloud compute instances stop atlantis-nonprod-vm --zone=europe-southwest1-b --project=alvarorg14-demo-pre \
  && gcloud compute instances start atlantis-nonprod-vm --zone=europe-southwest1-b --project=alvarorg14-demo-pre

gcloud compute instances stop atlantis-prod-vm --zone=europe-southwest1-b --project=alvarorg14-demo-pro \
  && gcloud compute instances start atlantis-prod-vm --zone=europe-southwest1-b --project=alvarorg14-demo-pro
```

Check the VM IPs again and update DNS if either changed. Once DNS propagates and
Caddy has obtained certificates, check the endpoints and containers:

```bash
curl -I https://atlantis-nonprod.alvarorg.com
curl -I https://atlantis-prod.alvarorg.com
gcloud compute ssh atlantis-nonprod-vm --zone=europe-southwest1-b --tunnel-through-iap --project=alvarorg14-demo-pre --command="sudo docker ps --format '{{.Names}} {{.Status}}'"
gcloud compute ssh atlantis-prod-vm --zone=europe-southwest1-b --tunnel-through-iap --project=alvarorg14-demo-pro --command="sudo docker ps --format '{{.Names}} {{.Status}}'"
```

## Step 9 — Set up `demo-atlantis-gsa`

Create the second repo with the layout from README §10
(`atlantis-nonprod.yaml`, `atlantis-prod.yaml`, `envs/{dev,pre,pro}`,
`modules/service-account`). Each Terraform root impersonates its runner:

```hcl
# envs/pre/providers.tf (example)
provider "google" {
  project = "alvarorg14-demo-pre"
  region  = "europe-southwest1"

  impersonate_service_account = "terraform-gsas-pre@alvarorg14-demo-pre.iam.gserviceaccount.com"
}
```

```hcl
# envs/pre/backend.tf (example)
terraform {
  backend "gcs" {
    bucket = "alvarorg14-terraform-state-gsa-pre"   # from environments/pre outputs
    prefix = "demo-atlantis-gsa/pre"
  }
}
```

Project names in the `atlantis-*.yaml` files must be `dev-gsas`, `pre-gsas`,
`pro-gsas` so each server only recognizes its own projects
(`ATLANTIS_SILENCE_NO_PROJECTS=true`).

---

## Step 10 — Protect the repositories

In **both** repos on GitHub:

- Branch protection on `main`: require PR reviews (≥1), require status checks
  (the Atlantis/CI checks), dismiss stale approvals, require linear history.
- Add a `CODEOWNERS` file (required review for production paths at minimum).
- In `demo-atlantis-gsa`, protect `main` so direct pushes are impossible —
  everything flows through Atlantis plan/apply.

---

## Step 11 — Verify everything

```bash
./scripts/verify.sh
```

Expected: 14 PASS, 0 FAIL — both VMs running, both HTTPS endpoints answering,
4141 closed from the internet, the full 6-case impersonation matrix, and
objectAdmin scoping on the three state buckets.

Then the end-to-end flow test:

```bash
# 1. Clone demo-atlantis-gsa, create a branch adding a trivial service account
git clone https://github.com/alvarorg14/demo-atlantis-gsa
cd demo-atlantis-gsa
git checkout -b test-atlantis
# ... edit envs/dev/main.tf to add a test GSA ...
git commit -am "test: add gsa" && git push -u origin test-atlantis
# 2. Open the PR -> NoPRO autoplan runs on dev-gsas and pre-gsas projects
# 3. Comment: atlantis-nonprod apply   (after reviewing the plan)
# 4. Merge -> PRO: comment atlantis-prod plan/apply on the same repo;
#    PRO requires a separate GitHub approval first.
```

✅ Check: Atlantis comments appear on the PR from the correct App
(`demo-atlantis-nonprod` for dev/pre, `demo-atlantis-prod` for pro).

---

## Command cheat sheet

```bash
# Terraform (any environment: pre, dev, pro)
./scripts/deploy.sh init <env>
./scripts/deploy.sh plan <env>
./scripts/deploy.sh apply <env>
./scripts/deploy.sh bootstrap

# Outputs
cd environments/<env> && terraform output && cd ../..

# VM access (IAP only, no public SSH)
gcloud compute ssh atlantis-nonprod-vm --tunnel-through-iap --project=alvarorg14-demo-pre
gcloud compute ssh atlantis-prod-vm    --tunnel-through-iap --project=alvarorg14-demo-pro

# Container logs
gcloud compute ssh atlantis-nonprod-vm --tunnel-through-iap --project=alvarorg14-demo-pre \
  --command="sudo docker logs atlantis-nonprod --tail 100"

# Startup script output (first-boot debugging)
gcloud compute instances get-serial-port-output atlantis-nonprod-vm --project=alvarorg14-demo-pre --zone=europe-southwest1-b

# Rotate a secret (then reboot the VM to re-read)
echo -n "<new-value>" | gcloud secrets versions add <secret-id> --project=<project> --data-file=-

# Full verification
./scripts/verify.sh
```

## Troubleshooting quick reference

| Symptom | Fix |
|---|---|
| Compose not running after boot | `get-serial-port-output` (above) — check the configuration and GitHub App secrets from steps 5 and 7 |
| TLS not issued | DNS not propagated yet, or ports 80/443 blocked — `gcloud compute firewall-rules list --project=<project>` |
| Webhook 403 | `X-Hub-Signature` mismatch: the App's webhook secret ≠ the one in the `…-gh-webhook-secret` secret |
| `atlantis-nonprod plan` ignored | PR branch isn't `main`, repo not in `ATLANTIS_REPO_ALLOWLIST`, or project not in `atlantis-nonprod.yaml` |
| Plan fails with impersonation error | TokenCreator missing — run `./scripts/verify.sh`, section 4 |
| PRO apply rejected | A GitHub review approval is required first (`apply_requirements: approved`) |

## Costs

Running 24/7: approximately $50–$60/month before tax (2× e2-small,
disks, public IPs, and light storage/network usage).
Destroy the environments when not demonstrating (README §15).
