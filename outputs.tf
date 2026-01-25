output "resource_group_name" {
  value = var.resource_group_name
}

output "virtual_network_id" {
  value = module.virtual_network.id
}

output "sql_server_id" {
  value       = azurerm_mssql_server.sql_server.id
  description = "The ID of the Azure SQL Server"
}

output "sql_server_fqdn" {
  value       = azurerm_mssql_server.sql_server.fully_qualified_domain_name
  description = "The fully qualified domain name of the SQL Server"
}

output "sql_database_id" {
  value       = azurerm_mssql_database.sql_database.id
  description = "The ID of the Azure SQL Database"
}

output "sql_private_endpoint_id" {
  value       = azurerm_private_endpoint.sql_private_endpoint.id
  description = "The ID of the SQL Server private endpoint"
}