# compliant-gcs-bucket

A GCS bucket module that hardcodes the security baseline for this compliance lab.
Consumers only choose business settings (environment, retention, naming); they
cannot disable any of the enforced controls below.

## Controls enforced

- **SC-12** — Customer-managed encryption key (CMEK) established via a dedicated
  KMS keyring and crypto key, owned by this project rather than Google.
- **SC-13 / SC-28** — Data is encrypted at rest with that CMEK, and the key
  rotates automatically every 90 days.
- **AC-3** — Uniform bucket-level access and enforced public access prevention
  ensure only authorized IAM principals can reach the bucket; the public cannot.
- **AU-11** — A retention policy enforces a minimum object retention period,
  with production environments requiring at least 365 days.
- **CM-6** — Required compliance labels (`project`, `environment`, `managed_by`,
  `compliance_scope`) are merged onto every bucket and cannot be removed by a
  consumer, even though consumers may add their own additional labels.

## Usage

See `terraform/primitives/compliant-gcs` (dev) and
`terraform/primitives/compliant-gcs-prod` (prod, plan-only) for example
consumers.