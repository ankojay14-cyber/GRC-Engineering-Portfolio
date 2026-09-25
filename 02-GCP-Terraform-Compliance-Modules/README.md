# Lab 2.4: Terraform Modules for Compliance (GCP)

A reusable Terraform module that deploys a NIST 800-53 compliant, CMEK-encrypted GCS bucket, called by two independent consumers — the second lab of the GRC Engineering Practitioner (CGE-P) certification program.

`Terraform` · `GCP` · `NIST 800-53` · Controls: SC-12, SC-13/SC-28, AC-3, AU-11, CM-6

> Part of the [CGEP capstone](https://github.com/ankojay14-cyber/cgep-labs) — a GRC Engineering Practitioner certification project.

## 1. What this lab is

Lab 2.3 deployed a single compliant resource by hand. This lab deploys a **module** — a reusable Terraform unit that provisions a customer-managed KMS key and a hardened GCS bucket, with the security baseline locked inside the module body where callers can't switch it off. Two consumers (`dev` and `prod`) call the same module with different business settings and inherit an identical security posture.

| Control | What is enforced |
|---|---|
| SC-12 | A customer-managed KMS keyring and crypto key are established and owned outside the provider |
| SC-13 / SC-28 | Data is encrypted at rest with that key (CMEK), rotating on a 90-day schedule |
| AC-3 | Uniform bucket-level access and enforced public access prevention |
| AU-11 | Object retention is enforced (≥365 days for `prod`, validated before any resource is created) |
| CM-6 | Required labels are merged onto every bucket; consumers can add labels but never remove the required ones |

All module code lives in `terraform/modules/compliant-gcs-bucket/`. It's consumed by `terraform/primitives/compliant-gcs/` (dev, applied), `compliant-gcs-prod/` (prod, plan-only), and `compliant-gcs-negative/` (a deliberate validation-failure demo). Evidence is captured to `evidence/lab-2-4/`.

## 2. Why it matters

This is the shift from deploying one compliant resource to deploying a **pattern**. A module's interface decides what a consumer is allowed to change; its body decides what's hardcoded. By hardcoding the security controls and exposing only business settings (environment, retention period, labels) through variables, a consumer can configure the bucket but never accidentally disable a control — because that choice was never offered.

It also introduces policy enforcement *before* deployment: the negative-test consumer intentionally sets an out-of-policy retention value, and Terraform refuses to even build a plan, catching the violation at the point a developer is already working — not in a later review or audit.

## 3. Key design decisions

**Module/consumer separation.** The security baseline lives entirely in `terraform/modules/compliant-gcs-bucket/`. Consumers under `terraform/primitives/` are a handful of lines of business config — they cannot touch the controls themselves.

**Add-but-not-remove labeling.** `effective_labels = merge(var.labels, local.required_labels)` lets a consumer pass extra labels, but the four required compliance labels are always merged on top last, so they can be added to but never suppressed.

**Split location variables.** GCS buckets accept multi-region locations like `US`; KMS keyrings require a single region. Keeping `location` and `kms_location` as separate variables (both defaulting to `us-central1`) avoids a `KMS_RESOURCE_NOT_FOUND_IN_LOCATION` error from an easy-to-make mistake.

**Plan-time retention validation.** A second `validation` block on `retention_days` enforces `>= 365` whenever `environment == "prod"`, rejecting a non-compliant plan before any resource is created — proven by the `compliant-gcs-negative` consumer, which fails on purpose.

**`retention_policy.is_locked = false`.** The lock is deliberately left off in this module so lab resources can still be destroyed. The `prod` consumer is only ever planned, never applied, specifically because a locked 365-day retention bucket can't be torn down.

## 4. Results

After `terraform apply` on the dev consumer, the module's `compliance_attestation` output (re-exposed by the consumer as `attestation`) confirms every control is active:

```
attestation = {
  "encryption_algorithm"     = "google-managed-cmek-aes256"
  "kms_rotation_period"      = "7776000s"
  "public_access_prevention" = "enforced"
  "required_labels_present"  = true
  "retention_period_days"    = 30
  "uniform_access_enforced"  = true
  "versioning_enabled"       = true
}
```

Running `terraform plan` against the negative-test consumer fails before creating anything:

```
Error: Invalid value for variable
  var.environment is "prod"
  var.retention_days is 30
retention_days must be >= 365 when environment == "prod".
```

That's the point of the lab: the policy is enforced by the module itself, at plan time, with no manual review required.

## 5. How to reproduce

**Prerequisites:** Terraform >= 1.6, Google Cloud CLI, a GCP project with billing and the Cloud KMS API enabled, `roles/storage.admin` and `roles/cloudkms.admin`, and both `gcloud auth login` and `gcloud auth application-default login` run (Terraform reads the second one, not the first).

**Deploy the dev consumer:**

```bash
cd terraform/primitives/compliant-gcs
terraform init
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
```

**Run the negative test (plan only — expected to fail):**

```bash
cd terraform/primitives/compliant-gcs-negative
terraform init
terraform plan
```

**Capture evidence:**

```bash
terraform -chdir=terraform/primitives/compliant-gcs show -json tfplan > evidence/lab-2-4/plan.json
terraform -chdir=terraform/primitives/compliant-gcs output -json attestation > evidence/lab-2-4/attestation.json
```

**Cleanup:**

```bash
cd terraform/primitives/compliant-gcs
terraform destroy -auto-approve
```

## Project structure

```
terraform/modules/compliant-gcs-bucket/
├── main.tf         # KMS keyring + rotating CMEK + hardened GCS bucket (SC-12, SC-13/28, AC-3, AU-11, CM-6)
├── variables.tf    # gcp_project, location, kms_location, project_label, environment, retention_days, bucket_name_suffix, labels
├── outputs.tf      # bucket_url, kms_key_id, compliance_attestation
└── README.md       # control summary

terraform/primitives/
├── compliant-gcs/            # dev consumer (applied)
├── compliant-gcs-prod/       # prod consumer (plan-only, 365-day retention lock)
└── compliant-gcs-negative/   # validation-failure demo (plan-only)

evidence/lab-2-4/
├── plan.json          # dev consumer's pre-deploy intent
└── attestation.json   # machine-readable compliance attestation
```

## Part of the CGEP Capstone

| Lab | Focus |
|---|---|
| 2.3 | Compliant S3 primitive |
| 2.4 | Compliant GCS module + consumers *(this repo)* |
| 2.5 | Evidence vault + capture script |
| 3.3 | Rego compliance policies + tests |
| 3.4 | AWS policy variants + Conftest gate |
