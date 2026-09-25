# Lab 3.4: Integrating Policy as Code with Terraform via Conftest (AWS)

AWS variants of the Lab 3.3 Rego policies, plus a `policy-gate.sh` script that turns Conftest into a fail-closed CI gate — the final lab of the GRC Engineering Practitioner (CGE-P) certification program.

`Conftest` · `OPA` · `Terraform` · `NIST 800-53` · Controls: SC-28, AC-3, CM-6

> Part of the [CGEP capstone](https://github.com/ankojay14-cyber/cgep-labs) — a GRC Engineering Practitioner certification project.

## 1. What this lab is

Lab 3.3 wrote three Rego policies against GCP fixtures. This lab proves those policies don't automatically work on AWS, then writes AWS variants that keep the same control IDs. `policies/sc28_encryption_aws.rego`, `ac3_no_public_aws.rego`, and `cm6_required_tags_aws.rego` check an AWS Terraform plan for the same three controls, and `scripts/policy-gate.sh` wraps Conftest into a single script a CI pipeline can call to block any pull request that violates a control.

## 2. Why it matters

A control ID is portable across clouds; a Rego rule that hardcodes a resource type is not. Running the GCP policies from Lab 3.3 against an AWS plan produces a "pass" — but only because the rules find zero matching resources to check. That's a dangerous kind of green: it looks like coverage and provides none. This lab is the lesson that a compliance library has to be built per-cloud, control by control, or it silently stops protecting anything the moment the underlying infrastructure changes provider. The payoff is `policy-gate.sh`: the exact script the capstone's CI pipeline runs on every PR, turning a manual security review into an automatic, fail-closed one.

## 3. Key design decisions

**AWS variants match by reference, not by value.** On AWS, encryption and public-access-block are separate resources that point at a bucket, not a nested block, and the bucket's real name is "known after apply" at plan time. The policies read `configuration.root_module.resources[].expressions.bucket.references` — strings like `"aws_s3_bucket.primary.id"` — to ask "is a compliant resource wired to this bucket?" rather than trying to match values that don't exist yet.

**AC-3 reads from both halves of the plan JSON.** `configuration` gives the wiring (which public-access-block belongs to which bucket); `planned_values` gives the actual flag values, since those are literal booleans the developer set, not deferred until apply. Knowing which half of a Terraform plan holds which kind of fact is the core skill behind every rule in this lab.

**CM-6's tag lookup falls back gracefully across three states.** A resource can carry tags merged by `default_tags` (`tags_all`), only locally-set tags (`tags`), or none at all — three separate `tag_keys` definitions handle each case, letting Rego pick the one that matches instead of writing an if/else chain.

**The gate script isolates namespace failures.** `policy-gate.sh` captures each Conftest namespace's exit status separately so one failing control doesn't stop the script before the others run — it collects every violation in one pass, not just the first.

**No GCP namespace in the gate.** The script only ever runs the `_aws` namespaces against an AWS plan — including a GCP namespace would reproduce the exact empty-pass problem the lab opens with.

## 4. Results

Running the GCP policies from Lab 3.3 against an AWS plan shows the empty-pass problem directly — they pass with zero coverage. Running the AWS variants against the same compliant plan shows real coverage:

```
=== compliance.sc28_aws ===
1 test, 1 passed, 0 warnings, 0 failures, 0 exceptions
=== compliance.ac3_aws ===
1 test, 1 passed, 0 warnings, 0 failures, 0 exceptions
=== compliance.cm6_aws ===
1 test, 1 passed, 0 warnings, 0 failures, 0 exceptions
```

Deleting the encryption resource from a throwaway copy and regenerating the plan makes the gate fire, with a non-zero exit code and a remediation message:

```
FAIL - compliance.sc28_aws - [SC-28] aws_s3_bucket.primary: aws_s3_bucket has no matching
aws_s3_bucket_server_side_encryption_configuration. Remediation: add one referencing this bucket.

1 test, 0 passed, 0 warnings, 1 failure, 0 exceptions
```

Both runs are captured as evidence in `evidence/lab-3-4/conftest-pass.json` and `conftest-fail.json`.

## 5. How to reproduce

**Prerequisites:** OPA >= 0.60.0, Conftest >= 0.50, Terraform >= 1.6, an AWS CLI profile (plan-only — nothing is applied).

**Generate a plan from the Lab 2.3 AWS code:**

```bash
cd terraform/primitives/compliant-s3
terraform init
terraform plan -out=tfplan -var="project_name=cgep-lab" -var="environment=dev"
terraform show -json tfplan > plan.json
cd ../../..
```

**Run the AWS policies against it:**

```bash
for ns in compliance.sc28_aws compliance.ac3_aws compliance.cm6_aws ; do
  conftest test --policy policies --namespace $ns terraform/primitives/compliant-s3/plan.json
done
```

**Run the gate script and capture evidence:**

```bash
bash scripts/policy-gate.sh --workspace terraform/primitives/compliant-s3
cp evidence/lab-3-4/conftest-results.json evidence/lab-3-4/conftest-pass.json
```

**Cleanup:** none required — this lab is entirely local plan evaluation; nothing is ever applied.

## Project structure

```
policies/
├── sc28_encryption_aws.rego     # SC-28: bucket has a matching encryption-config resource
├── ac3_no_public_aws.rego       # AC-3: bucket has a complete public-access-block (all 4 flags true)
├── cm6_required_tags_aws.rego   # CM-6: four required tags present (via tags_all or tags)
└── README.md                    # notes which policy file targets which cloud

scripts/
└── policy-gate.sh   # runs all three AWS namespaces via Conftest, fails closed on any violation

evidence/lab-3-4/
├── conftest-pass.json   # gate run against the compliant Lab 2.3 plan
└── conftest-fail.json   # gate run against a deliberately broken plan
```

## Part of the CGEP Capstone

| Lab | Focus |
|---|---|
| 2.3 | Compliant S3 primitive |
| 2.4 | Compliant GCS module + consumers |
| 2.5 | Evidence vault + capture script |
| 3.3 | Rego compliance policies + tests |
| 3.4 | AWS policy variants + Conftest gate *(this repo)* |
