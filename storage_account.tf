# ============================================================================
# Storage Account for SQL Auditing and Vulnerability Assessments
# ============================================================================

resource "azurerm_storage_account" "sql_audit_storage" {
  name                     = "sql${lower(replace(module.resource_group[local.default_environment].name, "-", ""))}"
  resource_group_name      = module.resource_group[local.default_environment].name
  location                 = module.resource_group[local.default_environment].location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  
  # Enable encryption at rest
  https_traffic_only_enabled = true
  min_tls_version            = "TLS1_2"

  # Network rules
  public_network_access_enabled = true
  shared_access_key_enabled     = true

  network_rules {
    default_action = "Deny"
    ip_rules       = ["0.0.0.0/0"]      # This allows all traffic, but it is better to be only your public IP address
    bypass         = ["AzureServices"]  # Optional: often needed for metrics/logging
  }

  tags = {
    purpose       = "sql-audit-and-vulnerability-assessment"
    encryption    = "enabled"
    compliance    = "required"
    environment   = local.default_environment
  }

  depends_on = [module.resource_group, azurerm_role_assignment.storage_blob_data_contributor]
}

# Blob container for SQL audit logs
resource "azurerm_storage_container" "sql_audit_logs" {
  name                  = "sql-audit-logs"
  storage_account_name  = azurerm_storage_account.sql_audit_storage.name
  container_access_type = "private"

  depends_on = [azurerm_storage_account.sql_audit_storage]
}

# Blob container for vulnerability assessments
resource "azurerm_storage_container" "vulnerability_assessments" {
  name                  = "vulnerability-assessments"
  storage_account_name  = azurerm_storage_account.sql_audit_storage.name
  container_access_type = "private"

  depends_on = [azurerm_storage_account.sql_audit_storage]
}
