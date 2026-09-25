# terraform/primitives/compliant-gcs-negative/main.tf
terraform {
  required_version = ">= 1.6"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 5.0" }
  }
}

provider "google" {
  project = "project-ac718b3e-a9c2-49e8-9ee"
  region  = "us-central1"
}

module "data_bucket" {
  source = "../../modules/compliant-gcs-bucket"

  gcp_project         = "project-ac718b3e-a9c2-49e8-9ee"
  project_label       = "cgep-lab"
  environment         = "prod"
  retention_days      = 30   # FAILS: prod requires >= 365
  bucket_name_suffix  = "should-never-exist"
}

output "attestation" { value = module.data_bucket.compliance_attestation }
output "bucket_url"   { value = module.data_bucket.bucket_url }
output "kms_key_id"   { value = module.data_bucket.kms_key_id }