# output "resource_group_name" {
#   value = var.resource_group_name
# }

# output "virtual_network_id" {
#   value = module.virtual_network.id
# }

# output "sql_server_id" {
#   value       = azurerm_mssql_server.sql_server.id
#   description = "The ID of the Azure SQL Server"
# }

# output "sql_server_fqdn" {
#   value       = azurerm_mssql_server.sql_server.fully_qualified_domain_name
#   description = "The fully qualified domain name of the SQL Server"
# }

# output "sql_database_id" {
#   value       = azurerm_mssql_database.sql_database.id
#   description = "The ID of the Azure SQL Database"
# }

# output "sql_private_endpoint_id" {
#   value       = azurerm_private_endpoint.sql_private_endpoint.id
#   description = "The ID of the SQL Server private endpoint"
# }

# output "sql_server_name" {
#   description = "The name of the SQL Server"
#   value       = azurerm_mssql_server.sql_server.name
# }

# output "tde_status" {
#   description = "Status of Transparent Data Encryption on SQL Server"
#   value = {
#     server_id           = azurerm_mssql_server_transparent_data_encryption.sql_tde.server_id
#     auto_rotation       = azurerm_mssql_server_transparent_data_encryption.sql_tde.auto_rotation_enabled
#   }
# }

# output "cmk_enabled" {
#   description = "Whether Customer-Managed Key encryption is enabled"
#   value       = var.enable_cmk_encryption
# }

# output "cmk_key_id" {
#   description = "The ID of the Customer-Managed Key used for SQL encryption"
#   value       = var.enable_cmk_encryption ? azurerm_key_vault_key.sql_cmk_key[0].id : "CMK not enabled"
# }

# output "keyvault_id" {
#   description = "The ID of the Key Vault for CMK encryption"
#   value       = azurerm_key_vault.sql_cmk_vault.id
# }

# output "sql_audit_storage_account_id" {
#   description = "The ID of the Storage Account for SQL audit logs"
#   value       = azurerm_storage_account.sql_audit_storage.id
# }

# output "sql_audit_storage_account_name" {
#   description = "The name of the Storage Account for SQL audit logs"
#   value       = azurerm_storage_account.sql_audit_storage.name
# }

# output "sql_extended_auditing_enabled" {
#   description = "Whether SQL Server extended auditing is enabled"
#   value       = azurerm_mssql_server_extended_auditing_policy.sql_security_alerts.enabled
# }

# output "audit_retention_days" {
#   description = "Number of days audit logs are retained"
#   value       = azurerm_mssql_server_extended_auditing_policy.sql_security_alerts.retention_in_days
# }

# output "vulnerability_assessment_enabled" {
#   description = "Whether SQL Vulnerability Assessment is enabled"
#   value       = var.enable_vulnerability_assessment
# }

# output "vulnerability_assessment_storage" {
#   description = "Storage account details for vulnerability assessment reports"
#   value = {
#     account_name = azurerm_storage_account.sql_audit_storage.name
#     container    = azurerm_storage_container.vulnerability_assessments.name
#   }
# }

# output "security_alerts_enabled" {
#   description = "Whether SQL Security Alerts are enabled"
#   value       = azurerm_mssql_server_extended_auditing_policy.sql_security_alerts.enabled
# }

# output "security_alert_retention_days" {
#   description = "Number of days security alert records are retained"
#   value       = azurerm_mssql_server_extended_auditing_policy.sql_security_alerts.retention_in_days
# }

# output "azure_policy_assignments" {
#   description = "Summary of Azure Policy assignments for SQL compliance"
#   value = {
#     tde_enabled_policy     = azurerm_subscription_policy_assignment.sql_tde_enabled.name
#     encryption_at_rest     = azurerm_subscription_policy_assignment.sql_encryption_at_rest.name
#     cmk_encryption_policy  = azurerm_subscription_policy_assignment.sql_cmk_encryption.name
#     firewall_policy        = azurerm_subscription_policy_assignment.sql_firewall_rules.name
#   }
# }

# output "sql_private_endpoint_ip" {
#   description = "The private IP address of the SQL Private Endpoint"
#   value       = azurerm_private_endpoint.sql_private_endpoint.private_service_connection[0].private_ip_address
# }

# output "keyvault_private_endpoint_id" {
#   description = "The ID of the Key Vault Private Endpoint"
#   value       = azurerm_private_endpoint.keyvault_private_endpoint.id
# }

# output "compliance_summary" {
#   description = "Summary of encryption and compliance status"
#   value = {
#     tde_enabled                  = true
#     cmk_encryption_enabled       = var.enable_cmk_encryption
#     auditing_enabled             = true
#     vulnerability_assessment     = var.enable_vulnerability_assessment
#     security_alerts_enabled      = var.enable_security_alerts
#     public_network_access        = azurerm_mssql_server.sql_server.public_network_access_enabled
#     private_endpoint_configured  = true
#     network_encryption_enforced  = true
#     retention_period_days        = var.sql_audit_retention_days
#     compliance_framework         = "Azure Policy + Terraform IaC"
#   }
# }
