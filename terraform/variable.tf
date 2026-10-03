variable "snowflake_organization_name" {
  type        = string
  description = "Snowflake organization name (the part before the dash in ORG-ACCOUNT)."
}

variable "snowflake_account_name" {
  type        = string
  description = "Snowflake account name (the part after the dash in ORG-ACCOUNT)."
}

variable "snowflake_user" {
  type        = string
  description = "Service user Terraform logs in as."
  default     = "TERRAFORM_SVC"
}

variable "snowflake_authenticator" {
  type        = string
  description = "Snowflake authentication method. Local use defaults to key-pair auth; CI uses WORKLOAD_IDENTITY."
  default     = "SNOWFLAKE_JWT"
}

variable "snowflake_private_key" {
  type        = string
  sensitive   = true
  description = "Optional PEM contents for local key-pair authentication."
  default     = ""
}

variable "snowflake_oidc_token" {
  type        = string
  sensitive   = true
  description = "Short-lived GitHub Actions OIDC token used by CI."
  default     = ""
}

variable "database_name" {
  type        = string
  description = "Name of the project database."
  default     = "ECOMMERCE_DB"
}

variable "loader_rsa_public_key" {
  type        = string
  description = "Public key body (no BEGIN/END lines) for LOADER_SVC."
}

variable "dbt_rsa_public_key" {
  type        = string
  description = "Public key body (no BEGIN/END lines) for DBT_SVC."
}

variable "human_user" {
  type        = string
  description = "Optional: your own Snowflake login name, so you can query the data with TRANSFORMER_ROLE."
  default     = ""
}
