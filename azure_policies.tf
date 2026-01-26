# Policy Assignment: Ensure Transparent Data Encryption (TDE) is enabled
# 1. Look up the policy definition by its built-in display name
data "azurerm_policy_definition" "tde_builtin" {
  display_name = "Transparent Data Encryption on SQL databases should be enabled"
}

# 2. Reference the data source ID in your assignment
resource "azurerm_subscription_policy_assignment" "sql_tde_enabled" {
  name                 = "enforce-sql-tde-enabled"
  subscription_id      = "/subscriptions/${var.ARM_SUBSCRIPTION_ID}"
  
  # This automatically provides the correct path format
  policy_definition_id = data.azurerm_policy_definition.tde_builtin.id
  
  description          = "Ensure that Transparent Data Encryption is enabled on SQL databases"
  display_name         = "SQL Database Transparent Data Encryption Must Be Enabled"
}

# Policy Assignment: Ensure server-side encryption is enabled for storage
resource "azurerm_subscription_policy_assignment" "sql_encryption_at_rest" {
  name                 = "enforce-sql-encryption-at-rest"
  subscription_id      = "/subscriptions/${var.ARM_SUBSCRIPTION_ID}"
  
  # FIXED: Removed subscription prefix
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/7698e800-9299-47a6-966f-8a8a4edd3f82"
  
  description          = "This policy ensures that transparent data encryption (TDE) is enabled for SQL databases"
  display_name         = "SQL Database Encryption-at-Rest Must Be Enabled"
  not_scopes           = []
}

# Policy Assignment: Ensure that SQL servers use Customer-Managed Keys (CMK)
resource "azurerm_subscription_policy_assignment" "sql_cmk_encryption" {
  name                 = "enforce-sql-cmk-encryption"
  subscription_id      = "/subscriptions/${var.ARM_SUBSCRIPTION_ID}"
  
  # FIXED: Removed subscription prefix
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/0a370ff3-6cab-4e85-8995-295fd854dee7"
  
  description          = "Enforce the use of Customer-Managed Keys for SQL Server encryption"
  display_name         = "SQL Servers Must Use Customer-Managed Keys for TDE"
  not_scopes           = []
}

# Policy Assignment: Ensure SQL databases have encryption enabled
resource "azurerm_subscription_policy_assignment" "sql_db_encryption" {
  name                 = "enforce-sql-db-encryption"
  subscription_id      = "/subscriptions/${var.ARM_SUBSCRIPTION_ID}"
  
  # FIXED: Removed subscription prefix
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/17k78e20-9358-41c9-923c-fb736d3e48ce"
  
  description          = "Audit SQL Databases that do not have Transparent Data Encryption enabled"
  display_name         = "Audit SQL Database Encryption Status"
  not_scopes           = []
}

# Policy Assignment: Ensure Azure SQL Server Firewall Rules Block All Access
resource "azurerm_subscription_policy_assignment" "sql_firewall_rules" {
  name                 = "enforce-sql-firewall-restrictions"
  subscription_id      = "/subscriptions/${var.ARM_SUBSCRIPTION_ID}"
  
  # FIXED: Removed subscription prefix
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/896822ca-2e6e-4df6-a60e-a38deedd2fbd"
  
  description          = "Ensure that 'Deny public network access' is set to 'True' for SQL Servers"
  display_name         = "SQL Server Public Network Access Must Be Denied"
  not_scopes           = []
}