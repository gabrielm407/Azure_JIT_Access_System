# ============================================================================
# Azure Policy Assignments for SQL Security and Encryption
# ============================================================================

# DATA SOURCES (Look up Policy Definitions for reference in assignments)
# Built-in Policy: Enables TDE on SQL Databases
data "azurerm_policy_definition" "tde_enabled" {
  display_name = "Transparent Data Encryption on SQL databases should be enabled"
}

# Built-in Policy: CMK for SQL Managed Instances
data "azurerm_policy_definition" "sql_mi_cmk" {
  display_name = "SQL managed instances should use customer-managed keys to encrypt data at rest"
}

# Built-in Policy: CMK for SQL Servers
data "azurerm_policy_definition" "sql_server_cmk" {
  display_name = "SQL servers should use customer-managed keys to encrypt data at rest"
}

# Built-in Policy: Deny Public Network Access
data "azurerm_policy_definition" "sql_public_access" {
  display_name = "Public network access on Azure SQL Database should be disabled"
}

# POLICY ASSIGNMENTS
# Policy Assignment: Ensure Transparent Data Encryption (TDE) is enabled
resource "azurerm_subscription_policy_assignment" "sql_tde_enabled" {
  name                 = "enforce-sql-tde-enabled"
  subscription_id      = "/subscriptions/${var.ARM_SUBSCRIPTION_ID}"
  policy_definition_id = data.azurerm_policy_definition.tde_enabled.id

  description  = "Ensure that Transparent Data Encryption is enabled on SQL databases"
  display_name = "SQL Database Transparent Data Encryption Must Be Enabled"
  not_scopes   = []
}

# Policy Assignment: Ensure CMK for SQL Managed Instances
resource "azurerm_subscription_policy_assignment" "sql_encryption_at_rest" {
  name                 = "enforce-sql-encryption-at-rest"
  subscription_id      = "/subscriptions/${var.ARM_SUBSCRIPTION_ID}"
  policy_definition_id = data.azurerm_policy_definition.sql_mi_cmk.id

  description  = "Enforce Customer-Managed Keys for SQL Managed Instances"
  display_name = "SQL Managed Instance CMK Encryption"
  not_scopes   = []
}

# Policy Assignment: Ensure that SQL servers use Customer-Managed Keys (CMK)
resource "azurerm_subscription_policy_assignment" "sql_cmk_encryption" {
  name                 = "enforce-sql-cmk-encryption"
  subscription_id      = "/subscriptions/${var.ARM_SUBSCRIPTION_ID}"
  policy_definition_id = data.azurerm_policy_definition.sql_server_cmk.id

  description  = "Enforce the use of Customer-Managed Keys for SQL Server encryption"
  display_name = "SQL Servers Must Use Customer-Managed Keys for TDE"
  not_scopes   = []
}

# # Policy Assignment: Ensure Azure SQL Server Firewall Rules Block All Access
# resource "azurerm_subscription_policy_assignment" "sql_firewall_rules" {
#   name                 = "enforce-sql-firewall-restrictions"
#   subscription_id      = "/subscriptions/${var.ARM_SUBSCRIPTION_ID}"
#   policy_definition_id = data.azurerm_policy_definition.sql_public_access.id

#   description          = "Ensure that 'Deny public network access' is set to 'True' for SQL Servers"
#   display_name         = "SQL Server Public Network Access Must Be Denied"
#   not_scopes           = []
# }
