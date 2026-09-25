# Lab 2.3: Building Your First Compliant Resource (AWS S3)

Terraform deployment of a NIST 800-53 compliant AWS S3 bucket — the foundational lab of the GRC Engineering Practitioner (CGE-P) certification program.

`Terraform` · `AWS S3` · `NIST 800-53` · Controls: SC-28, AC-3, CM-6, AU-3/AU-6

> Part of the [CGEP capstone](https://github.com/ankojay14-cyber/cgep-labs) — a GRC Engineering Practitioner certification project.

## 1. What this lab is

This lab provisions a compliant AWS S3 bucket using Terraform, enforcing four NIST 800-53 controls directly in the infrastructure code. A second dedicated log bucket is also provisioned to satisfy audit logging requirements. All resources are defined in `terraform/primitives/compliant-s3/` and produce machine-readable JSON evidence via `terraform show -json`.

| Control | What is enforced |
|---|---|
| SC-28 | AES-256 server-side encryption on both buckets |
| AC-3 | All four public access block flags explicitly set to `true` |
| CM-6 | Versioning enabled; four required tags applied at the provider level |
| AU-3 / AU-6 | Server access logging routed from the primary bucket to the dedicated log bucket |

## 2. Why it matters

This is the starting point of the compliance evidence chain. Before you can automate compliance enforcement or capture tamper-evident evidence, you need to understand exactly what a compliant resource looks like in Terraform — which controls apply, which AWS resources implement them, and what the JSON output proves.

A GRC engineer who can read a `terraform show -json` output and map it directly to a NIST control can answer an auditor's question in seconds with machine-readable proof instead of screenshots. This lab builds that skill from scratch.

It also establishes the baseline that every subsequent lab builds on:

- **Lab 2.5** locks the `plan.json` and `state.json` from this lab into an Object Lock vault as immutable audit evidence.
- **Lab 3.3** writes Rego policies that evaluate the `plan.json` from this lab before deployment.

## 3. Key design decisions

**Tags applied at the provider level, not per resource.** Rather than adding a `tags` block to each of the 11 resources individually, the required compliance tags (`Project`, `Environment`, `ManagedBy`, `ComplianceScope`) are set once in the AWS provider's `default_tags` block. This means every resource in the workspace automatically inherits them and they appear in `tags_all` in state — a single point of control for CM-6.

**Dedicated log bucket, not a shared one.** Server access logs go to a separate bucket (`aws_s3_bucket_logging`) rather than a folder in the primary bucket. This isolates audit logs from the data they're auditing and prevents a compromise of the primary bucket from also destroying its audit trail.

**Explicit public access block on both buckets.** Even though the log bucket isn't internet-facing, all four `aws_s3_bucket_public_access_block` flags are set on both buckets. This prevents any future policy change or IAM misconfiguration from accidentally making either bucket public.

## 4. Results

After `terraform apply`, `terraform show -json` produces a `state.json` confirming all controls are active. Key paths in the state file:

```
SC-28:  resources[aws_s3_bucket_server_side_encryption_configuration]
          .values.rule[0].apply_server_side_encryption_by_default[0].sse_algorithm
          = "AES256"

AC-3:   resources[aws_s3_bucket_public_access_block]
          .values.block_public_acls       = true
          .values.block_public_policy     = true
          .values.ignore_public_acls      = true
          .values.restrict_public_buckets = true

CM-6:   resources[*].values.tags_all
          = { Project, Environment, ManagedBy, ComplianceScope }

AU-3:   resources[aws_s3_bucket_logging]
          .values.target_bucket = <log bucket id>
```

These paths are what an auditor or automated policy (Lab 3.3) checks — no manual inspection required.

## 5. How to reproduce

**Prerequisites:** Terraform >= 1.6, AWS CLI with a configured default profile, permissions to create S3 resources.

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
terraform show -json        > ../../../evidence/lab-2-3/state.json
```

**Cleanup:**

```bash
terraform destroy -var="project_name=cgep-lab" -var="environment=dev"
```

## Project structure

```
terraform/primitives/compliant-s3/
├── main.tf         # 11 AWS resources covering SC-28, AC-3, CM-6, AU-3
├── variables.tf    # project_name, environment, bucket_suffix
└── outputs.tf      # Bucket ARNs and SC-28 attestation output

evidence/lab-2-3/
├── plan.json       # Pre-deploy intent (terraform show -json tfplan)
└── state.json      # Post-deploy state confirming controls are active
```

## Part of the CGEP Capstone

| Lab | Focus |
|---|---|
| 2.3 | Compliant S3 primitive *(this repo)* |
| 2.4 | Compliant GCS module + consumers |
| 2.5 | Evidence vault + capture script |
| 3.3 | Rego compliance policies + tests |
| 3.4 | AWS policy variants + Conftest gate |
