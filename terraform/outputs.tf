output "database" {
  value = snowflake_database.main.name
}

output "schemas" {
  value = [snowflake_schema.raw.name, snowflake_schema.staging.name, snowflake_schema.marts.name]
}

output "warehouses" {
  value = [snowflake_warehouse.loading.name, snowflake_warehouse.transforming.name]
}

output "roles" {
  value = [snowflake_account_role.loader.name, snowflake_account_role.transformer.name]
}
