# Compliant S3 Primitive

Terraform deployment of a NIST 800-53 compliant AWS S3 bucket — Lab 2.3 of the GRC Engineering Practitioner (CGE-P) certification program.

## 1. What this lab is

This primitive provisions a compliant AWS S3 bucket using Terraform, enforcing four NIST 800-53 controls directly in the infrastructure code. A second dedicated log bucket is also provisioned to satisfy audit logging requirements. All resources are defined in `main.tf` and produce machine-readable JSON evidence via `terraform show -json`.

| Control | What is enforced |
|---|---|
| SC-28 | AES-256 server-side encryption on both buckets |
| AC-3 | All four public access block flags explicitly set to `true` |
| CM-6 | Versioning enabled; four required tags applied at the provider level |
| AU-3 / AU-6 | Server access logging routed from the primary bucket to the dedicated log bucket |

## 2. Why it matters

This is the starting point of the compliance evidence chain. A GRC engineer who can read a `terraform show -json` output and map it directly to a NIST control can answer an auditor's question in seconds with machine-readable proof instead of screenshots.

## 3. Key design decisions

**Tags applied at the provider level.** Required compliance tags (`Project`, `Environment`, `ManagedBy`, `ComplianceScope`) are set once in the AWS provider's `default_tags` block, so every resource inherits them automatically — a single point of control for CM-6.

**Dedicated log bucket.** Server access logs go to a separate bucket (`aws_s3_bucket.log`) rather than a folder in the primary bucket, isolating audit logs from the data they're auditing.

**Explicit public access block on both buckets.** All four `aws_s3_bucket_public_access_block` flags are set on both buckets, even though the log bucket isn't internet-facing.

**Random suffix on bucket names.** A `random_id` resource appends a unique suffix to both bucket names, since S3 bucket names are globally unique across all of AWS.

## 4. Results

Verified evidence from `state.json`:

Deployment output:

## 5. How to reproduce

**Prerequisites:** Terraform >= 1.6, AWS CLI with a configured `default` profile.

**Deploy:**
```bash
cd terraform/primitives/compliant-s3
terraform init
terraform plan -var="project_name=cgep-lab" -var="environment=dev" -out=tfplan
terraform apply -auto-approve tfplan
```

**Capture evidence:**
```bash
terraform show -json tfplan > ../../../evidence/lab-2-3/plan.json
terraform show -json       > ../../../evidence/lab-2-3/state.json
```

**Cleanup:**
```bash
terraform destroy -auto-approve -var="project_name=cgep-lab" -var="environment=dev"
```

## Project structure
