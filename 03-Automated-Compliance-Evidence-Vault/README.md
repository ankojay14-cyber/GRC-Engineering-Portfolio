# Lab 2.5: IaC as Compliance Evidence (AWS)

An S3 Object Lock vault and capture script that turn Terraform output into tamper-resistant compliance evidence — the third lab of the GRC Engineering Practitioner (CGE-P) certification program.

`Terraform` · `AWS S3 Object Lock` · `Bash` · Evidence: Integrity, Attribution, Reproducibility

> Part of the [CGEP capstone](https://github.com/ankojay14-cyber/cgep-labs) — a GRC Engineering Practitioner certification project.

## 1. What this lab is

Labs 2.3 and 2.4 built compliant resources. This lab proves they stayed compliant. It builds two pieces: an **evidence vault** — an S3 bucket with Object Lock enabled at creation, so nothing written to it can be deleted before its retention expires — and a **capture script** that packages a Terraform workspace's plan, state, git commit, and version info into a SHA-256-hashed bundle, uploads it to the vault, and prints a JSON receipt.

Vault code lives in `terraform/primitives/evidence-vault/`, the script in `scripts/capture-evidence.sh`, and a sample receipt in `evidence/lab-2-5/receipt.json`. This vault isn't a lab throwaway — it's the same evidence vault the rest of the capstone writes to.

## 2. Why it matters

Auditors care about three properties in evidence: **integrity** (it hasn't been altered), **attribution** (you can tell who produced it), and **reproducibility** (anyone can regenerate or re-verify it). A screenshot of a console delivers none of these. A hashed bundle of Terraform plan/state, committed to git and locked in a vault that physically refuses deletion, delivers all three automatically — no one has to trust that the evidence wasn't touched after the fact, because the infrastructure guarantees it.

## 3. Key design decisions

**Object Lock enabled at bucket creation, not retrofitted.** Object Lock can only be set when a bucket is created — there's no upgrade path for an existing bucket. The vault is built immutable from birth, with versioning enabled as Object Lock's prerequisite.

**GOVERNANCE vs. COMPLIANCE retention modes.** GOVERNANCE mode allows a privileged caller to bypass retention (`--bypass-governance-retention`), so lab work can be torn down. COMPLIANCE mode allows no one — not even the account root — to delete a locked object before retention expires. The workflow is identical either way; only the mode changes between practice and production use.

**Explicit deny on bucket deletion.** A bucket policy denies `s3:DeleteBucket` to everyone except the account root, so the vault itself can't be casually removed even if its objects could be freed.

**Every captured file is hashed into a manifest.** The script computes a SHA-256 for the plan, state, commit log, and Terraform version file, recording each in `manifest.json` — any post-capture tampering becomes detectable.

**Fail-safe cleanup in the script.** `set -euo pipefail` plus a `trap` on exit means a partial or failed capture cleans up its temp files rather than leaving artifacts behind.

## 4. Results

Running the capture script against a live workspace produces a receipt like:

```json
{"run_id":"test-001","vault":"cgep-lab-grc-evidence-vault-XXXXXXXX","key":"runs/test-001/bundle.tar.gz","version_id":"<base64-version-id>","captured_at_utc":"<iso-utc-timestamp>"}
```

Checking the uploaded object confirms retention was applied automatically, without ever being set by hand:

```json
{ "Retention": { "Mode": "GOVERNANCE", "RetainUntilDate": "<retain-until-utc>" } }
```

The proof of the whole lab is the destructive test: attempting to delete that same object returns

```
An error occurred (AccessDenied) when calling the DeleteObject operation:
Access Denied because object protected by object lock.
```

That rejection is the evidence vault delivering on its promise — protection an administrator can't quietly bypass.

## 5. How to reproduce

**Prerequisites:** AWS CLI profile, `sha256sum` or `shasum`, Terraform >= 1.6, optionally Cosign for bundle signing.

**Deploy the vault:**

```bash
cd terraform/primitives/evidence-vault
terraform init
terraform apply -auto-approve
VAULT=$(terraform output -raw vault_name)
```

**Capture evidence from a live workspace:**

```bash
bash scripts/capture-evidence.sh \
  --workspace terraform/primitives/compliant-s3 \
  --run-id    test-001 \
  --vault     "$VAULT" \
  --profile   default > evidence/lab-2-5/receipt.json
```

**Verify the retention took hold:**

```bash
aws s3api get-object-retention --bucket "$VAULT" --key runs/test-001/bundle.tar.gz --profile default
```

**Confirm it can't be deleted (expected to fail):**

```bash
aws s3api delete-object --bucket "$VAULT" --key runs/test-001/bundle.tar.gz --version-id <version-id> --profile default
```

**Cleanup (GOVERNANCE mode only):** bypass-delete the locked object, then:

```bash
cd terraform/primitives/evidence-vault
terraform destroy -auto-approve
```

## Project structure

```
terraform/primitives/evidence-vault/
├── main.tf         # Object Lock bucket, versioning, retention rule, encryption, public-access block, deny-delete-bucket policy
├── variables.tf    # project_name, lock_mode (GOVERNANCE/COMPLIANCE), retention_days
└── outputs.tf      # vault_name

scripts/
└── capture-evidence.sh   # hashes + bundles a Terraform workspace's plan/state/commit/version, uploads to the vault, prints a JSON receipt

evidence/lab-2-5/
└── receipt.json    # run_id, vault, key, version_id, captured_at_utc for a captured evidence bundle
```

## Part of the CGEP Capstone

| Lab | Focus |
|---|---|
| 2.3 | Compliant S3 primitive |
| 2.4 | Compliant GCS module + consumers |
| 2.5 | Evidence vault + capture script *(this repo)* |
| 3.3 | Rego compliance policies + tests |
| 3.4 | AWS policy variants + Conftest gate |
