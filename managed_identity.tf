# ============================================================================
# Managed Identity and Role Assignments
# ============================================================================

resource "azurerm_user_assigned_identity" "user" {
  name                = "user-managed-identity"
  location            = module.resource_group[local.default_environment].location
  resource_group_name = module.resource_group[local.default_environment].name
}

resource "azurerm_role_assignment" "contributor" {
  scope                = module.resource_group[local.default_environment].resource_group_id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.user.principal_id
}

resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  scope                = module.resource_group[local.default_environment].resource_group_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.user.principal_id
}

resource "azurerm_role_assignment" "func_sql_security_manager" {
  scope                = azurerm_mssql_server.sql_server.id
  role_definition_name = "SQL Security Manager"
  principal_id         = azurerm_linux_function_app.jit_function.identity[0].principal_id
}

# Role Assignment for SQL Server to access Key Vault
resource "azurerm_role_assignment" "sql_keyvault_access" {
  count                = var.enable_cmk_encryption ? 1 : 0
  scope                = azurerm_key_vault.sql_cmk_vault.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_mssql_server.sql_server.identity[0].principal_id

  depends_on = [
    azurerm_key_vault.sql_cmk_vault,
    azurerm_mssql_server.sql_server
  ]
}
