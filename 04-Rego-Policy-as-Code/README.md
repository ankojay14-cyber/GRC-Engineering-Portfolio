# Lab 3.3: Writing Compliance Policies in Rego (GCP)

Three Rego policies and their tests that read a Terraform plan and refuse it before deployment if it violates a control — the fourth lab of the GRC Engineering Practitioner (CGE-P) certification program.

`Rego` · `Open Policy Agent (OPA)` · `NIST 800-53` · Controls: SC-28, AC-3, CM-6

> Part of the [CGEP capstone](https://github.com/ankojay14-cyber/cgep-labs) — a GRC Engineering Practitioner certification project.

## 1. What this lab is

Every earlier lab built compliant infrastructure. This lab builds the thing that *checks* infrastructure, automatically, before it's ever deployed. Three Rego policies read a Terraform plan (`plan.json`) and produce `deny` messages when a resource violates a control — an empty deny set means compliant infrastructure. Each policy ships with a companion test file proving it stays quiet on good infrastructure and speaks up on bad.

| Control | File | What it requires |
|---|---|---|
| SC-28 | `policies/sc28_encryption.rego` | Every GCS bucket has a customer-managed encryption key |
| AC-3 | `policies/ac3_no_public.rego` | Buckets aren't public; firewalls don't open ports 22/3389 to `0.0.0.0/0` |
| CM-6 | `policies/cm6_required_tags.rego` | Every taggable resource carries the four required labels |

Policies and tests live at the repo root in `policies/` — exactly where the capstone expects them. A throwaway, plan-only test fixture (`terraform/primitives/policy-fixture/`) provides infrastructure to check against — one compliant bucket and three deliberately broken ones, plus an open firewall. Evidence is captured to `evidence/lab-3-3/opa-test-results.json`.

## 2. Why it matters

This is the moment a control stops being a sentence in a document and becomes a program that runs. Every deny message names the resource *and* the NIST control (`[SC-28] google_storage_bucket.bad_no_cmek: missing customer-managed encryption key`), so a developer fixes it themselves — no GRC ticket, no meeting, no human in the loop. The check runs in under a second against a plan, before anything is ever deployed, closing the loop this whole capstone builds toward: compliance enforced by the pipeline, not discovered by an auditor after the fact.

## 3. Key design decisions

**Every rule carries a `# METADATA` block.** Each policy file states its control ID, NIST framework, severity, and remediation directly above the code. This is the GRC bridge in machine-readable form — a tool (or an auditor) can read what control a policy implements without opening the logic.

**Denies recurse into `child_modules`, not just `root_module.resources`.** A resource declared through a Terraform module (like the Lab 2.4 GCS module) is nested under `child_modules` in the plan JSON, not the top level. Every policy here checks both, deliberately — missing this is the single easiest way to write a policy that silently ignores every module-wrapped resource.

**`has_cmek` checks for the block's existence, not a populated value.** At plan time, a KMS key ID is often "known after apply" and omitted from the JSON. Requiring a non-empty string would wrongly fail correct code; the policy only fails when the `encryption` block is missing or explicitly empty.

**Label comparison uses set subtraction, not array logic.** `required - provided` only works when both sides are Rego sets. `provided_labels` is written as a set comprehension specifically so the built-in `-` operator can compute exactly which required labels are missing.

**Tests always come in pairs.** Every policy has a `test_compliant_passes` and a `test_noncompliant_fails` — proving both halves of the claim: quiet on good infrastructure, vocal on bad. A policy without both is a policy nobody should trust.

## 4. Results

Running the full library against the test fixture's plan:

```
opa test -v policies/
# PASS: 8/8
```

Evaluating each policy against the real fixture plan flags exactly the resources that are broken, and nothing else:

```
[SC-28] google_storage_bucket.bad_no_cmek: missing customer-managed encryption key.
Remediation: add encryption { default_kms_key_name = ... }.

[AC-3] google_compute_firewall.open_ssh: management port 22 open to 0.0.0.0/0.
[AC-3] google_storage_bucket.bad_public: bucket allows public access.

[CM-6] google_storage_bucket.bad_no_labels: missing required labels
["compliance_scope", "environment", "managed_by", "project"].
```

The compliant bucket (`good`) never appears in any deny set. Fixing each violation in the fixture and re-running the evals returns every deny set empty — the full developer feedback loop, in under a minute, with no reviewer involved.

## 5. How to reproduce

**Prerequisites:** OPA >= 0.60.0, Terraform >= 1.6, a GCP project (the fixture only ever plans, never applies).

**Generate the plan the policies read:**

```bash
cd terraform/primitives/policy-fixture
terraform init
terraform plan -out=tfplan -var=gcp_project=your-gcp-project
terraform show -json tfplan > plan.json
cd ../../..
```

**Run the unit tests:**

```bash
opa test -v policies/
```

**Evaluate each policy against the real plan:**

```bash
opa eval -d policies -i terraform/primitives/policy-fixture/plan.json data.compliance.sc28.deny --format=pretty
opa eval -d policies -i terraform/primitives/policy-fixture/plan.json data.compliance.ac3.deny  --format=pretty
opa eval -d policies -i terraform/primitives/policy-fixture/plan.json data.compliance.cm6.deny  --format=pretty
```

**Capture evidence:**

```bash
opa test --format=json policies/ > evidence/lab-3-3/opa-test-results.json
```

**Cleanup:** none required — the fixture is plan-only and nothing is ever applied.

## Project structure

```
policies/
├── sc28_encryption.rego       # SC-28: every bucket has a CMEK
├── ac3_no_public.rego         # AC-3: no public buckets, no open management ports
├── cm6_required_tags.rego     # CM-6: four required labels on every taggable resource
├── README.md                  # control, severity, remediation per policy
└── tests/
    ├── sc28_encryption_test.rego
    ├── ac3_no_public_test.rego
    └── cm6_required_tags_test.rego

terraform/primitives/policy-fixture/
└── main.tf         # one compliant bucket, three deliberately broken buckets, one open firewall (plan-only)

evidence/lab-3-3/
└── opa-test-results.json   # captured `opa test` output
```

## Part of the CGEP Capstone

| Lab | Focus |
|---|---|
| 2.3 | Compliant S3 primitive |
| 2.4 | Compliant GCS module + consumers |
| 2.5 | Evidence vault + capture script |
| 3.3 | Rego compliance policies + tests *(this repo)* |
| 3.4 | AWS policy variants + Conftest gate |
