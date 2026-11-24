# Atlantis policy integration

Atlantis runs the same reviewed `policies/gsa.rego` from read-only local mounts in both VMs. Secret Manager holds separate copies and each runtime identity has access only to its own secret. Conftest 0.70.1 is pinned in CI to match the v0.48.2 image build; verify the actual running images as below. No credentials or plan JSON are published by CI. Repository branch protection must require the `opa-policy-tests` status check and reviews on `main`; an administrator must configure this in GitHub Settings → Branches/rulesets. The workflow runs on every PR to main so the required check is not skipped.

Atlantis permits a policy owner to approve a failed policy set as an exception. The initial owner is `alvarorg14`, with self-approval disabled; their own PRs therefore cannot obtain exceptions until an independent owner is added. Do not enable sticky approvals without a separate review. Existing plan/apply requirements still apply. This is policy gating with an explicit owner-controlled exception mechanism, not an absolute prohibition against an authorized exception.

Critical unknown values are denied. In particular the existing GSA module derives IAM `member` from the new service account's computed email, which Terraform may mark unknown on the first plan. If so, a GSA with roles cannot pass in one plan: create the account with no roles, apply, then add approved roles in a later PR, and verify the member is known. Do not weaken the rule or change the module as part of this integration. Provider-default projects are not accepted without explicit planned values. Existing disallowed no-op resources are tolerated, but changing them or deleting any resource is denied.

## Review and deploy (operator only)

The implementation does not apply Terraform, publish secrets, modify GitHub settings, restart VMs, or create test PRs. Review and merge all changes to main first. Confirm the Terraform validation workflow and `opa-policy-tests` pass, and configure the required check and branch reviews. From a clean checkout of reviewed main:

```bash
git fetch origin main
scripts/test-policies.sh
scripts/deploy.sh plan pre
scripts/deploy.sh apply pre
scripts/deploy.sh plan pro
scripts/deploy.sh apply pro
scripts/publish-policies.sh
```

The publish script validates before uploading and publishes only the policy and tests matching `origin/main`; fetch it first and ensure branch protection requires review. It reports version names. Uploads are sequential: if the second fails, the first version remains published; resolve and rerun before restarting either VM. Review secret version states and contents before proceeding. Publication does not reload running containers.

Check the running image on **each** VM before rollout (set `ZONE` to the deployed zone):

```bash
ZONE=europe-southwest1-b
gcloud compute ssh atlantis-nonprod-vm --project=alvarorg14-demo-pre --zone="$ZONE" --tunnel-through-iap --command='sudo docker exec atlantis-nonprod conftest --version'
gcloud compute ssh atlantis-prod-vm --project=alvarorg14-demo-pro --zone="$ZONE" --tunnel-through-iap --command='sudo docker exec atlantis-prod conftest --version'
```

Ensure both report 0.70.1; stop and investigate incompatibilities before deployment. The real `.env` files live in Secret Manager; do not upload the examples over them. Update each current secret in a private temporary directory, preserving every existing setting. Inspect and remove any duplicate values for these two keys before appending:

```bash
umask 077
workdir=$(mktemp -d)
for target in 'alvarorg14-demo-pre nonprod' 'alvarorg14-demo-pro prod'; do
  read -r project env <<< "$target"
  gcloud secrets versions access latest --project="$project" --secret="atlantis-$env-env-file" > "$workdir/$env.env"
  sed -i '/^ATLANTIS_ENABLE_POLICY_CHECKS=/d; /^ATLANTIS_DATA_DIR=/d' "$workdir/$env.env"
  printf '\nATLANTIS_ENABLE_POLICY_CHECKS=true\nATLANTIS_DATA_DIR=/atlantis-data\n' >> "$workdir/$env.env"
  # Review the resulting file privately before uploading; it may contain sensitive values.
  gcloud secrets versions add "atlantis-$env-env-file" --project="$project" --data-file="$workdir/$env.env"
  gcloud secrets versions add "atlantis-$env-compose" --project="$project" --data-file="deployments/$env/compose.yaml"
  gcloud secrets versions add "atlantis-$env-repos-yaml" --project="$project" --data-file="deployments/$env/repos.yaml"
done
rm -rf "$workdir"
```

Do not print the `.env` file or credentials in logs. Confirm enabled versions exist in both projects, including the policy secret, before restarting. The VM startup script fetches latest secrets only at boot; `docker compose restart` alone does **not** fetch them. Schedule downtime. In each environment, starting with NoPRO, stop the old Atlantis container and disable its Docker restart policy before reboot, so Docker cannot resurrect an unprotected old configuration before startup fetches the new configuration:

```bash
gcloud compute ssh atlantis-nonprod-vm --project=alvarorg14-demo-pre --zone="$ZONE" --tunnel-through-iap --command='sudo docker update --restart=no atlantis-nonprod && sudo docker stop atlantis-nonprod'
gcloud compute instances reset atlantis-nonprod-vm --project=alvarorg14-demo-pre --zone="$ZONE"
```

After NoPRO recovers and passes the PR checks below, repeat for PRO using `atlantis-prod`, `atlantis-prod-vm` and `alvarorg14-demo-pro`. Startup fetches secrets, recreates the stack and sets the Compose restart policy. If startup fails, leave Atlantis stopped, investigate startup logs, and fix missing versions/configuration before retrying. A controlled operator invocation of the installed startup script can also reload secrets; a simple service restart cannot. Moving the configured data directory may leave old data in the former container home; assess existing locks, plans and database state before rollout, and do not apply stale plans. Check persistence by recreating the container during the maintenance window and comparing its data on the attached disk.

After both rollouts, run `ZONE="$ZONE" scripts/verify-policies.sh`. It uses IAP SSH and requires Compute OS Login, Docker sudo and Secret Manager metadata access. It verifies enabled secret versions, effective flags, repo configuration, read-only policy mount, Conftest compilation, disk mount, data writability and container health. Review Atlantis PR status checks and comments for policy results; inspect logs with `gcloud compute ssh ... --command='sudo docker logs --tail 200 atlantis-nonprod'` and boot logs with `sudo journalctl -u google-startup-scripts.service`. Keep plan output private.

## Controlled PR verification

Use disposable branches and resources in `demo-atlantis-gsa`; do not merge the negative tests. On NoPRO test: (1) create a valid DEV/PRE GSA without roles; (2) temporarily relax module name validation in the test branch and produce an invalid-name plan; (3) add `roles/owner` to an existing disposable GSA, making sure its principal is known; (4) plan removal of a disposable GSA and its IAM members, temporarily removing `prevent_destroy` in the test branch if needed; (5) add an unauthorized resource whose plan succeeds. Confirm the first passes and each remaining policy check fails and blocks apply; never apply the prohibited changes. Then use an approved PRO PR with a valid disposable GSA, run the manual PRO plan and verify both GitHub plan approval and policy checks. Clean up test branches without deleting production resources. If the principal is unknown, the owner-role test may fail for that reason too; inspect the policy result and use a known principal to demonstrate the role check.
