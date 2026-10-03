provider "snowflake" {
  organization_name = var.snowflake_organization_name
  account_name      = var.snowflake_account_name
  user              = var.snowflake_user
  role              = "ACCOUNTADMIN" # simplification for a trial account - see docs/ARCHITECTURE.md
  authenticator     = var.snowflake_authenticator
  private_key       = var.snowflake_private_key != "" ? var.snowflake_private_key : null
  token             = var.snowflake_oidc_token != "" ? var.snowflake_oidc_token : null

  workload_identity_provider = var.snowflake_authenticator == "WORKLOAD_IDENTITY" ? "OIDC" : null
}
