############################################
# Database and schemas (medallion-style layers)
############################################
resource "snowflake_database" "main" {
  name                        = var.database_name
  data_retention_time_in_days = 1
  comment                     = "Real-time e-commerce analytics platform (managed by Terraform)"
}

resource "snowflake_schema" "raw" {
  database = snowflake_database.main.name
  name     = "RAW"
  comment  = "Landing zone: data exactly as received. Never edited."
}

resource "snowflake_schema" "staging" {
  database = snowflake_database.main.name
  name     = "STAGING"
  comment  = "dbt staging models: cleaned and typed."
}

resource "snowflake_schema" "marts" {
  database = snowflake_database.main.name
  name     = "MARTS"
  comment  = "dbt marts: business-ready tables."
}

############################################
# Warehouses (compute) - one per workload
############################################
resource "snowflake_warehouse" "loading" {
  name                = "LOADING_WH"
  warehouse_size      = "XSMALL"
  auto_suspend        = 60
  auto_resume         = true
  initially_suspended = true
  comment             = "Used by the Python ingestion job"
}

resource "snowflake_warehouse" "transforming" {
  name                = "TRANSFORMING_WH"
  warehouse_size      = "XSMALL"
  auto_suspend        = 60
  auto_resume         = true
  initially_suspended = true
  comment             = "Used by dbt"
}

############################################
# Raw landing table and internal stage
############################################
resource "snowflake_table" "orders_raw" {
  database = snowflake_database.main.name
  schema   = snowflake_schema.raw.name
  name     = "ORDERS_RAW"
  comment  = "One row per order event, JSON kept as VARIANT"

  column {
    name = "PAYLOAD"
    type = "VARIANT"
  }
  column {
    name = "SOURCE_FILE"
    type = "VARCHAR"
  }
  column {
    name = "LOADED_AT"
    type = "TIMESTAMP_LTZ"
  }
}

resource "snowflake_stage" "orders" {
  database = snowflake_database.main.name
  schema   = snowflake_schema.raw.name
  name     = "ORDERS_STAGE"
  comment  = "Internal stage: the Python job uploads JSON files here, then COPY INTO loads them."
}

locals {
  fq_raw_schema     = "\"${snowflake_database.main.name}\".\"${snowflake_schema.raw.name}\""
  fq_staging_schema = "\"${snowflake_database.main.name}\".\"${snowflake_schema.staging.name}\""
  fq_marts_schema   = "\"${snowflake_database.main.name}\".\"${snowflake_schema.marts.name}\""
  fq_orders_table   = "\"${snowflake_database.main.name}\".\"${snowflake_schema.raw.name}\".\"${snowflake_table.orders_raw.name}\""
  fq_orders_stage   = "\"${snowflake_database.main.name}\".\"${snowflake_schema.raw.name}\".\"${snowflake_stage.orders.name}\""
}

############################################
# Roles (least privilege: one per job)
############################################
resource "snowflake_account_role" "loader" {
  name    = "LOADER_ROLE"
  comment = "Can only upload to the stage and load into RAW.ORDERS_RAW"
}

resource "snowflake_account_role" "transformer" {
  name    = "TRANSFORMER_ROLE"
  comment = "dbt: reads RAW, builds STAGING and MARTS"
}

# ---- LOADER_ROLE grants ----
resource "snowflake_grant_privileges_to_account_role" "loader_db" {
  account_role_name = snowflake_account_role.loader.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.main.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "loader_wh" {
  account_role_name = snowflake_account_role.loader.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.loading.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "loader_schema" {
  account_role_name = snowflake_account_role.loader.name
  privileges        = ["USAGE"]
  on_schema {
    schema_name = local.fq_raw_schema
  }
}

resource "snowflake_grant_privileges_to_account_role" "loader_table" {
  account_role_name = snowflake_account_role.loader.name
  privileges        = ["INSERT", "SELECT"]
  on_schema_object {
    object_type = "TABLE"
    object_name = local.fq_orders_table
  }
}

resource "snowflake_grant_privileges_to_account_role" "loader_stage" {
  account_role_name = snowflake_account_role.loader.name
  privileges        = ["READ", "WRITE"]
  on_schema_object {
    object_type = "STAGE"
    object_name = local.fq_orders_stage
  }
}

# ---- TRANSFORMER_ROLE grants ----
resource "snowflake_grant_privileges_to_account_role" "transformer_db" {
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["USAGE", "CREATE SCHEMA"] # CREATE SCHEMA lets dbt make per-developer / per-PR schemas
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.main.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_wh" {
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.transforming.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_raw_schema" {
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["USAGE"]
  on_schema {
    schema_name = local.fq_raw_schema
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_raw_table" {
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["SELECT"]
  on_schema_object {
    object_type = "TABLE"
    object_name = local.fq_orders_table
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_staging" {
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["USAGE", "CREATE TABLE", "CREATE VIEW"]
  on_schema {
    schema_name = local.fq_staging_schema
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_marts" {
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["USAGE", "CREATE TABLE", "CREATE VIEW"]
  on_schema {
    schema_name = local.fq_marts_schema
  }
}

############################################
# Service users (key-pair auth, no passwords)
############################################
resource "snowflake_user" "loader" {
  name              = "LOADER_SVC"
  default_role      = snowflake_account_role.loader.name
  default_warehouse = snowflake_warehouse.loading.name
  rsa_public_key    = var.loader_rsa_public_key
  comment           = "Service user for the Python ingestion job"
}

resource "snowflake_user" "dbt" {
  name              = "DBT_SVC"
  default_role      = snowflake_account_role.transformer.name
  default_warehouse = snowflake_warehouse.transforming.name
  rsa_public_key    = var.dbt_rsa_public_key
  comment           = "Service user for dbt"
}

resource "snowflake_grant_account_role" "loader_to_user" {
  role_name = snowflake_account_role.loader.name
  user_name = snowflake_user.loader.name
}

resource "snowflake_grant_account_role" "transformer_to_user" {
  role_name = snowflake_account_role.transformer.name
  user_name = snowflake_user.dbt.name
}

# Optional: lets you (a human) query everything with TRANSFORMER_ROLE
resource "snowflake_grant_account_role" "transformer_to_human" {
  count     = var.human_user == "" ? 0 : 1
  role_name = snowflake_account_role.transformer.name
  user_name = var.human_user
}
