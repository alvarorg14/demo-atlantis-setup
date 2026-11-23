# Bootstrap

Creates the three **administrative** Terraform state buckets for
`demo-atlantis-setup`, one per project:

| Project | Bucket |
|---|---|
| `alvarorg14-demo-dev` | `alvarorg14-terraform-state-dev` |
| `alvarorg14-demo-pre` | `alvarorg14-terraform-state-pre` |
| `alvarorg14-demo-pro` | `alvarorg14-terraform-state-pro` |

All buckets get object versioning, uniform bucket-level access and public
access prevention.

This step runs **outside Atlantis**, before any `terraform init` of the
environment directories. The operator needs `storage.admin` (or the
`storage.buckets.create` / `storage.buckets.get` / `storage.objects.*`
equivalents) on the three projects.

The `demo-atlantis-gsa` state buckets (`alvarorg14-terraform-state-gsa-{dev,pre,pro}`)
are *not* created here; they are provisioned by Terraform in each environment
and accessed by the restricted execution GSAs.

## Usage

```bash
cd bootstrap
BUCKET_LOCATION=europe-southwest1 ./create-state-buckets.sh
```

| Variable | Default | Purpose |
|---|---|---|
| `BUCKET_LOCATION` | `europe-southwest1` | GCS location for the buckets. |

The script is idempotent: existing buckets are detected and left untouched
(their versioning setting is re-checked).

At the end it prints the `terraform init` commands for the three environments.
