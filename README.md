# demo-atlantis-setup

Deploys and configures two secure **Atlantis** instances on **Google Cloud
Platform**, integrated with **GitHub** and **Terraform**, simulating an
enterprise environment with three separate GCP projects:

| Environment | Project ID | Purpose |
|---|---|---|
| DEV | `alvarorg14-demo-dev` | Development infrastructure |
| PRE | `alvarorg14-demo-pre` | Preproduction infrastructure and **Atlantis NoPRO** |
| PRO | `alvarorg14-demo-pro` | Production infrastructure and **Atlantis PRO** |

The second repository, `demo-atlantis-gsa`, contains Terraform configurations
for creating Google Cloud service accounts **through** Atlantis. This
repository provisions the Atlantis platform itself.

Objective: demonstrate least-privilege IAM, service-account impersonation,
GitHub integration and production isolation.

> **Quickstart:** follow [QUICKSTART.md](QUICKSTART.md) for the complete
> ordered deployment walkthrough.

---

## 1. Architecture

```text
                                   ┌───────────────────────────────┐
                                   │           GitHub              │
                                   │  repo: demo-atlantis-gsa      │
                                   │  (only repo managed by        │
                                   │   Atlantis)                   │
                                   └──────┬───────────────┬────────┘
                                          │ webhooks      │
                    ┌─────────────────────┘               └──────────────┐
                    │ GitHub App: demo-atlantis-nonprod   GitHub App: demo-atlantis-prod
                    │ (own key/webhook secret)            (own key/webhook secret)
                    ▼                                                    ▼
┌───────────────────────────────────────┐          ┌───────────────────────────────────────┐
│  PRE: alvarorg14-demo-pre             │          │  PRO: alvarorg14-demo-pro             │
│                                       │          │                                       │
│  ┌─────────────────────────────────┐  │          │  ┌─────────────────────────────────┐  │
│  │ VM atlantis-nonprod (e2-small)  │  │          │  │ VM atlantis-prod (e2-small)     │  │
│  │  Docker: Atlantis v0.48.2       │  │          │  │  Docker: Atlantis v0.48.2       │  │
│  │   + Caddy 2.10.2 (TLS :443)     │  │          │  │   + Caddy 2.10.2 (TLS :443)     │  │
│  │  SA: atlantis-nonprod@…-pre     │  │          │  │  SA: atlantis-prod@…-pro        │  │
│  │  /events  (4141 loopback only)  │  │          │  │  /events  (4141 loopback only)  │  │
│  └───────────────┬─────────────────┘  │          │  └───────────────┬─────────────────┘  │
│                  │ impersonates       │          │                  │ impersonates       │
│                  ▼                    │          │                  ▼                    │
│  terraform-gsas-pre@alvarorg14-demo-  │          │  terraform-gsas-pro@alvarorg14-demo-  │
│  pre.iam.gserviceaccount.com          │          │  pro.iam.gserviceaccount.com          │
│  (serviceAccountCreator on PRE)       │          │  (serviceAccountCreator on PRO)       │
└────────────┬──────────────────────────┘          └──────────────────┬────────────────────┘
             │ impersonates                                           │ impersonates
             ▼                                                        ▼
┌───────────────────────────────────────┐          ┌───────────────────────────────────────┐
│  DEV: alvarorg14-demo-dev             │          │  PRO: alvarorg14-demo-pro             │
│  terraform-gsas-dev@…-dev             │          │  (same runner as above)               │
│  (serviceAccountCreator on DEV)       │          │                                       │
└───────────────────────────────────────┘          └───────────────────────────────────────┘

State buckets (demo-atlantis-setup, admin/operator only — created by bootstrap):
  alvarorg14-terraform-state-{dev,pre,pro}

State buckets (demo-atlantis-gsa, restricted runner identities):
  alvarorg14-terraform-state-gsa-{dev,pre,pro}
```

**Impersonation matrix** (TokenCreator, bound directly to each target GSA):

| Principal | DEV runner | PRE runner | PRO runner |
|---|---|---|---|
| Atlantis NoPRO (`atlantis-nonprod@…-pre`) | ✅ | ✅ | ❌ |
| Atlantis PRO (`atlantis-prod@…-pro`) | ❌ | ❌ | ✅ |

## 2. Repository structure

```text
demo-atlantis-setup/
├── README.md
├── .gitignore
├── .terraform-version          # Terraform 1.17.2
├── versions.tf                 # shared required_providers (google ~> 6.0)
├── variables.tf                # shared project IDs + bucket location
│
├── bootstrap/
│   ├── README.md
│   └── create-state-buckets.sh # admin state buckets (runs outside Atlantis)
│
├── environments/
│   ├── dev/                    # DEV runner GSA + DEV gsa-state bucket + NoPRO→DEV binding
│   ├── pre/                    # NoPRO VM + PRE runner + PRE gsa-state bucket
│   └── pro/                    # PRO VM + PRO runner + PRO gsa-state bucket
│
├── modules/
│   ├── terraform-runner/       # restricted execution GSA + serviceAccountCreator
│   ├── state-bucket/           # versioned, UBLA, PPA-enforced GCS bucket
│   └── atlantis-vm/            # shielded VM + network + secrets + startup script
│
├── deployments/
│   ├── nonprod/                # compose.yaml, repos.yaml, Caddyfile, .env.example
│   └── prod/                   # compose.yaml, repos.yaml, Caddyfile, .env.example
│
├── scripts/
│   ├── deploy.sh               # bootstrap / init / plan / apply wrapper
│   └── verify.sh               # post-deployment checks (VMs, TLS, IAM, 4141)
│
└── .github/workflows/
    └── terraform-validate.yml  # fmt + validate + yaml + shellcheck + tfsec
```

## 3. Prerequisites

- `gcloud` CLI, authenticated:
  `gcloud auth application-default login` with an identity that can, in the
  three projects:
  - create and bind IAM service accounts
  - create GCS buckets
  - provision Compute Engine (networks, firewalls, VMs, disks)
  - create Secret Manager secrets
- Terraform `1.17.2` (matches `.terraform-version`; use `tfenv` or manual install)
- `jq`, `curl`, `openssl` (for verification and secret generation)
- DNS control for the two public hostnames
- GitHub organization (or user) admin to create and install the two GitHub Apps
- The three GCP projects must exist and billing enabled

## 4. Bootstrap (step 1 — outside Atlantis)

Creates the three **administrative** state buckets for this repository
(`alvarorg14-terraform-state-{dev,pre,pro}`).

```bash
cd bootstrap
BUCKET_LOCATION=europe-southwest1 ./create-state-buckets.sh
cd ..
```

Alternatively: `./scripts/deploy.sh bootstrap`.

## 5. Terraform initialization and deployment

The environments use a **partial** GCS backend; the bucket is supplied at
`init` time. Deployment order: **pre → dev → pro** (pre creates the NoPRO
runtime SA that dev binds impersonation to).

```bash
# 1. PRE (hosts Atlantis NoPRO)
./scripts/deploy.sh init pre
./scripts/deploy.sh plan pre     # review
./scripts/deploy.sh apply pre

# 2. DEV (DEV runner + NoPRO→DEV impersonation)
./scripts/deploy.sh init dev
./scripts/deploy.sh plan dev
./scripts/deploy.sh apply dev

# 3. PRO (hosts Atlantis PRO; independent state)
./scripts/deploy.sh init pro
./scripts/deploy.sh plan pro
./scripts/deploy.sh apply pro
```

Bucket names are fixed (`alvarorg14-terraform-state-{dev,pre,pro}`); no suffix
configuration needed.

Grab the VM public IPs:

```bash
cd environments/pre  && terraform output atlantis_nonprod_public_ip && cd ../..
cd environments/pro  && terraform output atlantis_prod_public_ip   && cd ../..
```

## 6. IAM permissions matrix

| Identity | Grants | Explicitly denied |
|---|---|---|
| `terraform-gsas-dev@alvarorg14-demo-dev` | `iam.serviceAccountCreator` on `alvarorg14-demo-dev`; `storage.objectAdmin` on `alvarorg14-terraform-state-gsa-dev` | owner, editor, `iam.serviceAccountAdmin`, `resourcemanager.projectIamAdmin`, project Storage Admin, SA key creation, access to other buckets/projects |
| `terraform-gsas-pre@alvarorg14-demo-pre` | `iam.serviceAccountCreator` on `alvarorg14-demo-pre`; `storage.objectAdmin` on `alvarorg14-terraform-state-gsa-pre` | same as above |
| `terraform-gsas-pro@alvarorg14-demo-pro` | `iam.serviceAccountCreator` on `alvarorg14-demo-pro`; `storage.objectAdmin` on `alvarorg14-terraform-state-gsa-pro` | same as above |
| `atlantis-nonprod@alvarorg14-demo-pre` (VM SA) | TokenCreator on DEV and PRE runners; `secretmanager.secretAccessor` on its own secrets only | any PRO resource, project IAM administration, bucket access |
| `atlantis-prod@alvarorg14-demo-pro` (VM SA) | TokenCreator on PRO runner; `secretmanager.secretAccessor` on its own secrets only | any DEV/PRE resource, project IAM administration, bucket access |

No service-account JSON keys are created anywhere in this setup; the VMs use
their attached GSAs, and the Terraform roots use impersonation.

## 7. GCS state configuration

Two bucket families (all with versioning, uniform bucket-level access,
public access prevention):

| Family | Buckets | Who applies | Backend identity |
|---|---|---|---|
| `alvarorg14-terraform-state-{env}` | 3, by bootstrap | the operator (this repo's environments) | administrator / infrastructure-deployment identity |
| `alvarorg14-terraform-state-gsa-{env}` | 3, by Terraform (modules/state-bucket) | the runner GSAs via Atlantis (`demo-atlantis-gsa` repo) | the corresponding `terraform-gsas-<env>` |

In `demo-atlantis-gsa`, each Terraform root must impersonate its environment's
execution GSA for **both** the Google provider and the GCS backend (see
section 10). The setup repository never uses the restricted runner identities.

## 8. Secrets and Secret Manager

The VM module pre-creates per-environment secrets. Nothing secret passes
through Terraform variables, VM metadata, startup scripts or state.

| Secret (in the VM's project) | Content | Filled by |
|---|---|---|
| `atlantis-nonprod-env-file` / `atlantis-prod-env-file` | full `.env` for the container (flags; no GitHub creds) | operator (from `deployments/<env>/.env.example`) |
| `atlantis-nonprod-compose` / `atlantis-prod-compose` | `compose.yaml` content | operator (from `deployments/<env>/compose.yaml`) |
| `atlantis-nonprod-repos-yaml` / `atlantis-prod-repos-yaml` | server-side `repos.yaml` | operator (from `deployments/<env>/repos.yaml`) |
| `atlantis-nonprod-caddyfile` / `atlantis-prod-caddyfile` | `Caddyfile` content | operator (from `deployments/<env>/Caddyfile`) |
| `atlantis-nonprod-gh-app-id` / `atlantis-prod-gh-app-id` | GitHub App ID | operator, after creating the App |
| `atlantis-nonprod-gh-app-key` / `atlantis-prod-gh-app-key` | GitHub App private key (PEM) | operator, generated once by GitHub |
| `atlantis-nonprod-gh-webhook-secret` / `atlantis-prod-gh-webhook-secret` | GitHub App webhook secret | operator (`openssl rand -hex 32`) |

Each runtime GSA gets `secretmanager.secretAccessor` **only on its own
project's secrets** — cross-environment access is impossible by construction.

Push example (PRE):

```bash
cd deployments/nonprod
# edit .env (real hostnames), then:
gcloud secrets versions add atlantis-nonprod-env-file   --project=alvarorg14-demo-pre --data-file=.env
gcloud secrets versions add atlantis-nonprod-compose    --project=alvarorg14-demo-pre --data-file=compose.yaml
gcloud secrets versions add atlantis-nonprod-repos-yaml --project=alvarorg14-demo-pre --data-file=repos.yaml
gcloud secrets versions add atlantis-nonprod-caddyfile  --project=alvarorg14-demo-pre --data-file=Caddyfile
```

GitHub credentials (do the equivalent for `prod` / `alvarorg14-demo-pro`):

```bash
echo -n "<APP_ID>"  | gcloud secrets versions add atlantis-nonprod-gh-app-id          --project=alvarorg14-demo-pre --data-file=-
openssl rand -hex 32 > /tmp/noprod-webhook-secret.txt
gcloud secrets versions add atlantis-nonprod-gh-webhook-secret --project=alvarorg14-demo-pre --data-file=/tmp/noprod-webhook-secret.txt
# download the App private key from GitHub, then:
gcloud secrets versions add atlantis-nonprod-gh-app-key --project=alvarorg14-demo-pre --data-file=app-private-key.pem
```

## 9. GitHub App setup

Create **two independent Apps** (Settings → Developer settings → GitHub Apps →
New GitHub App):

| Setting | App 1 | App 2 |
|---|---|---|
| Name | `demo-atlantis-nonprod` | `demo-atlantis-prod` |
| Homepage URL | `https://atlantis-nonprod.alvarorg.com` | `https://atlantis-prod.alvarorg.com` |
| Webhook URL | `https://atlantis-nonprod.alvarorg.com/events` | `https://atlantis-prod.alvarorg.com/events` |
| Webhook secret | value of `atlantis-nonprod-gh-webhook-secret` | value of `atlantis-prod-gh-webhook-secret` |
| SSL verification | enabled | enabled |
| Permissions | Repository: Administration (r), Contents (r), Pull requests (rw), Commit statuses (rw), Issues (rw) — same for both | |
| Subscribe to events | Pull request, Issue comment, Push | same |
| Install on | `demo-atlantis-gsa` **only** | `demo-atlantis-gsa` **only** |

For each App: generate a private key → store as `…-gh-app-key`; note the App ID
→ `…-gh-app-id`. Install the App exclusively on `demo-atlantis-gsa`.

Never reuse keys, App IDs, webhook secrets or endpoints between the two Apps.

## 10. demo-atlantis-gsa repository (the Atlantis side)

```text
demo-atlantis-gsa/
├── atlantis-nonprod.yaml     # projects: dev-gsas, pre-gsas
├── atlantis-prod.yaml        # projects: pro-gsas
├── envs/
│   ├── dev/                  # Terraform root: impersonates terraform-gsas-dev
│   ├── pre/                  # Terraform root: impersonates terraform-gsas-pre
│   └── pro/                  # Terraform root: impersonates terraform-gsas-pro
└── modules/
    └── service-account/
```

Each root's `providers.tf` + backend impersonate its environment's runner:

```hcl
terraform {
  backend "gcs" {
    bucket = "alvarorg14-terraform-state-gsa-pre"  # from this repo's outputs
    prefix = "demo-atlantis-gsa/pre"
  }
}

provider "google" {
  project = "alvarorg14-demo-pre"
  region  = "europe-southwest1"

  impersonate_service_account = "terraform-gsas-pre@alvarorg14-demo-pre.iam.gserviceaccount.com"
}
```

Atlantis project names (referenced in the two `atlantis-*.yaml` files):
`dev-gsas`, `pre-gsas`, `pro-gsas`. NoPRO recognizes only the first two;
PRO only the third (`--silence-no-projects=true` enforces it server-side).

All state bucket names and service-account emails are exposed as **outputs**
of this repository's environments (see section 13).

## 11. DNS and HTTPS

- Point both hostnames (A record) at the VM public IPs from the outputs:
  - `atlantis-nonprod.alvarorg.com` → `atlantis_nonprod_public_ip` (PRE)
  - `atlantis-prod.alvarorg.com` → `atlantis_prod_public_ip` (PRO)
- Caddy obtains Let's Encrypt certificates automatically over HTTP-01
  (ports 80/443 open); keep both open.
- Update the site address in each `Caddyfile` and `ATLANTIS_ATLANTIS_URL` in
  each `.env` secret if you change hostnames, then re-run the compose up.

TLS terminates at Caddy; Atlantis itself binds to `127.0.0.1:4141` on the VM
and is **never** publicly reachable (firewall deny rule + loopback binding).

## 12. VM administration

- SSH only via **IAP**: `gcloud compute ssh <vm-name> --tunnel-through-iap --project=<project>`
- OS Login enabled; the VM's own GSA gets `roles/compute.osLogin`.
- Port 4141 is firewall-denied from all sources.
- Reboot recovery: the startup script is re-run on every boot (installs Docker
  if missing, re-mounts the data disk, re-runs compose; containers use
  `restart: unless-stopped`).
- Atlantis data persists on the dedicated 10 GB data disk (`/etc/atlantis`),
  formatted only on first boot.

## 13. Verification

Run the full check suite after deployment:

```bash
./scripts/verify.sh
```

Checks: both VMs running, HTTPS endpoints responding, port 4141 closed,
impersonation matrix (all 6 cases), state bucket scoping.

Key outputs per environment:

```bash
cd environments/pre && terraform output && cd ../..
cd environments/pro && terraform output && cd ../..
cd environments/dev && terraform output && cd ../..
```

| Output | Meaning |
|---|---|
| `atlantis_nonprod_sa_email` | NoPRO runtime GSA (used in DEV binding) |
| `terraform_{dev,pre,pro}_sa_email` | restricted runner identities |
| `gsa_state_{dev,pre,pro}_bucket` | buckets for `demo-atlantis-gsa` backends |
| `atlantis_{nonprod,prod}_public_ip` | DNS targets |
| `atlantis_{nonprod,prod}_url` | expected public endpoints |

### Troubleshooting

| Symptom | Check |
|---|---|
| 502 from Caddy | `docker logs atlantis-nonprod` — container crashed; check `/opt/atlantis/.env` and `repos.yaml` |
| Certificate not issued | DNS not pointing at the VM yet, or port 80 blocked |
| Webhooks not received | URL must be `https://<host>/events`; check the webhook secret matches `…-gh-webhook-secret` |
| `atlantis-nonprod plan` ignored | Repo not in `ATLANTIS_REPO_ALLOWLIST`, project not in `atlantis-nonprod.yaml`, or branch ≠ `main` |
| Impersonation error in plan | TokenCreator binding missing (verify with `./scripts/verify.sh`) |
| Startup script failed | `gcloud compute instances get-serial-port-output <vm> --project=<project>` |

## 14. Expected infrastructure costs (approximate, europe-southwest1)

| Resource | Spec | Monthly (approx.) |
|---|---|---|
| 2 × e2-small VM | 0.5 shared vCPU / 2 GB each | ~$14.50 each → **~$29** |
| 2 × 30 GB pd-balanced boot | | ~$2.50 each → ~$5 |
| 2 × 10 GB pd-balanced data | | ~$1 each → ~$2 |
| 2 × ephemeral public IP | Attached to running VMs | ~$7.30 |
| 6 × GCS state buckets | < 1 GB total | < $1 |
| Secret Manager | 14 secrets with one version each, negligible access | < $1 |
| Network egress | modest (git clones, terraform downloads) | variable, small |
| **Total** | Light demo traffic, before tax | **~$50–$60 / month** |

Tear down when not demonstrating to avoid charges.

## 15. Cleanup / destruction

```bash
# 1. Destroy environments (order: pro → dev → pre; pro/pre delete their VMs)
cd environments/pro && terraform destroy && cd ../..
cd environments/dev && terraform destroy -var="atlantis_nonprod_sa_email=atlantis-nonprod@alvarorg14-demo-pre.iam.gserviceaccount.com" && cd ../..
cd environments/pre && terraform destroy && cd ../..

# 2. Delete the demo-atlantis-gsa state buckets (created by the runners)
gcloud storage rm --recursive gs://alvarorg14-terraform-state-gsa-dev --project=alvarorg14-demo-dev
gcloud storage rm --recursive gs://alvarorg14-terraform-state-gsa-pre --project=alvarorg14-demo-pre
gcloud storage rm --recursive gs://alvarorg14-terraform-state-gsa-pro --project=alvarorg14-demo-pro

# 3. Delete the administrative state buckets
gcloud storage rm --recursive gs://alvarorg14-terraform-state-dev --project=alvarorg14-demo-dev
gcloud storage rm --recursive gs://alvarorg14-terraform-state-pre --project=alvarorg14-demo-pre
gcloud storage rm --recursive gs://alvarorg14-terraform-state-pro --project=alvarorg14-demo-pro

# 4. Remove the GitHub Apps and their installations
```

State buckets are `force_destroy=false` — empty them first. Deleting the state
buckets is the point of no return: after this the Terraform state is gone.

## 16. Security boundaries and limitations

**Environment isolation**

- NoPRO can impersonate DEV and PRE runners; never PRO (no binding exists).
- PRO can impersonate only the PRO runner.
- Each runner GSA has permissions in its own project only.
- State buckets are scoped per runner (`storage.objectAdmin` on its own bucket).
- Runtime GSAs cannot administer project IAM policies.
- PRO and NoPRO VMs, identities, GitHub credentials, secrets and persistent
  data are fully disjoint.

**GitHub security**

- Protected `main` branch with required PR reviews and CODEOWNERS (configure in
  both repositories).
- Webhook signature validation (`--gh-webhook-secret` per App).
- Exact repository allowlist (`ATLANTIS_REPO_ALLOWLIST`, no wildcards).
- Server-side repo config (`repos.yaml`), `allow_custom_workflows: false`,
  `allowed_overrides: []`, `ATLANTIS_DISABLE_APPLY_ALL=true`,
  `--allow-fork-prs=false`.
- PRO requires GitHub **approval** for both plan and apply
  (`plan_requirements`/`apply_requirements: approved`).

**Secrets**

- No GSA JSON keys anywhere; impersonation only.
- No committed credentials; `.env`, `*.pem` are gitignored.
- GitHub App keys and webhook secrets live only in Secret Manager.
- Nothing secret is in Terraform state, variables, metadata or startup scripts.

**Known security limitation**

Terraform plans execute code via provider plugins and data sources. Atlantis
NoPRO has access to both the DEV and PRE execution identities, making it a
**shared nonproduction trust boundary**. PRO is isolated through separate
infrastructure, credentials and GCP IAM, but Atlantis project routing and
Terraform provider configuration must **not** be treated as sufficient
security boundaries on their own: anyone able to open a PR that changes
Terraform code executes code as the runner identity. Mitigate with branch
protection, CODEOWNERS, and required approvals.
