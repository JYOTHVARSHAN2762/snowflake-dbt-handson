terraform {
  required_version = ">= 1.6.0"

  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "~> 2.21"
    }
  }

  # Remote state in HCP Terraform (free tier). Organization and workspace are supplied through the
  # environment variables TF_CLOUD_ORGANIZATION and TF_WORKSPACE (see docs/USER_MANUAL.md, Phase 3).
  cloud {}
}
