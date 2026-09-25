# Compliance Policies

| Control | File | Severity | Remediation |
|---|---|---|---|
| SC-28 | `sc28_encryption.rego` | High | Add an `encryption { default_kms_key_name = ... }` block referencing a `google_kms_crypto_key` you control. |
| AC-3 | `ac3_no_public.rego` | Critical | Set `uniform_bucket_level_access = true`, `public_access_prevention = enforced`. For firewalls, narrow `source_ranges` or remove the rule. |
| CM-6 | `cm6_required_tags.rego` | Medium | Add the four required labels (`project`, `environment`, `managed_by`, `compliance_scope`) to the resource. |

## Policy files by cloud

- GCP: sc28_encryption.rego, ac3_no_public.rego, cm6_required_tags.rego
- AWS: sc28_encryption_aws.rego, ac3_no_public_aws.rego, cm6_required_tags_aws.rego