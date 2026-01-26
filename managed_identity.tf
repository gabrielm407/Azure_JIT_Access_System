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
  principal_id         = azurerm_user_assigned_identity.user.principal_id
}