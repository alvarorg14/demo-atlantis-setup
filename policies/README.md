# GSA guardrails

`gsa.rego` is the shared trusted policy for Atlantis Conftest's `main` namespace. It checks managed Terraform resource changes, refusing deletions and replacements, other changed resource types, invalid GSA IDs/projects, and project IAM members whose role, project or service-account principal is not explicitly valid and known. Unchanged resources and data sources are not restricted. Only the three specified projects and two roles are accepted. Missing or unknown critical values fail closed.

The policy is distributed from reviewed setup repository code, never the GSA PR checkout. An Atlantis policy owner can approve an exception, as described in `docs/opa-integration.md`; this is an explicit bypass and must be governed accordingly. Run `scripts/test-policies.sh` with Conftest 0.70.1 and Python 3. See `tests/README.md` for fixtures.
