# ============================================================================ 
# Azure SQL Server with Security and Encryption Configuration
# ============================================================================

# Azure SQL Server with Public Network Access enabled
resource "azurerm_mssql_server" "sql_server" {
  name                          = "sqlserver-${lower(replace(module.resource_group[local.default_environment].name, "-", ""))}"
  resource_group_name           = module.resource_group[local.default_environment].name
  location                      = "East US 2"
  tags                          = module.resource_group[local.default_environment].tags
  version                       = "12.0"
  administrator_login           = var.sql_admin_username
  administrator_login_password  = var.sql_admin_password
  public_network_access_enabled = true

  # Enable managed identity for use with Customer-Managed Keys (CMK)
  identity {
    type = "SystemAssigned"
  }
}

# Azure SQL Database
resource "azurerm_mssql_database" "sql_database" {
  name           = "sentineldb"
  server_id      = azurerm_mssql_server.sql_server.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  sku_name       = "S0"
  zone_redundant = false

  tags = module.resource_group[local.default_environment].tags
}

# Private Endpoint for SQL Server
resource "azurerm_private_endpoint" "sql_private_endpoint" {
  name                = "${azurerm_mssql_server.sql_server.name}-private-endpoint"
  resource_group_name = module.resource_group[local.default_environment].name
  location            = module.resource_group[local.default_environment].location
  subnet_id           = module.virtual_network.subnet_id

  private_service_connection {
    name                           = "${azurerm_mssql_server.sql_server.name}-psc"
    private_connection_resource_id = azurerm_mssql_server.sql_server.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  tags = module.resource_group[local.default_environment].tags
}

# Private DNS Zone for SQL Server
resource "azurerm_private_dns_zone" "sql_dns" {
  name                = "privatelink.database.windows.net"
  resource_group_name = module.resource_group[local.default_environment].name

  tags = module.resource_group[local.default_environment].tags
}

# Private DNS Zone Virtual Network Link
resource "azurerm_private_dns_zone_virtual_network_link" "sql_vnet_link" {
  name                  = "${azurerm_mssql_server.sql_server.name}-vnet-link"
  resource_group_name   = module.resource_group[local.default_environment].name
  private_dns_zone_name = azurerm_private_dns_zone.sql_dns.name
  virtual_network_id    = module.virtual_network.id
}

# DNS A Record for SQL Server`
resource "azurerm_private_dns_a_record" "sql_dns_record" {
  name                = azurerm_mssql_server.sql_server.name
  zone_name           = azurerm_private_dns_zone.sql_dns.name
  resource_group_name = module.resource_group[local.default_environment].name
  ttl                 = 300
  records             = [azurerm_private_endpoint.sql_private_endpoint.private_service_connection[0].private_ip_address]
}

# Transparent Data Encryption (TDE) Configuration
# Enable TDE with service-managed key (default)
resource "azurerm_mssql_server_transparent_data_encryption" "sql_tde" {
  server_id             = azurerm_mssql_server.sql_server.id
  auto_rotation_enabled = true
}

# Advanced Data Security Configuration
resource "azurerm_mssql_server_extended_auditing_policy" "sql_security_alerts" {
  server_id         = azurerm_mssql_server.sql_server.id
  enabled           = true
  retention_in_days = 30

  depends_on = [azurerm_mssql_server_transparent_data_encryption.sql_tde]
}

# Security Alert Policy
resource "azurerm_mssql_server_security_alert_policy" "sql_security_alerts" {
  resource_group_name = module.resource_group[local.default_environment].name
  server_name         = azurerm_mssql_server.sql_server.name
  state               = "Enabled"
}

# Vulnerability Assessment
resource "azurerm_mssql_server_vulnerability_assessment" "sql_vulnerability_assessment" {
  server_security_alert_policy_id = azurerm_mssql_server_security_alert_policy.sql_security_alerts.id
  storage_container_path          = "${azurerm_storage_account.sql_audit_storage.primary_blob_endpoint}vulnerability-assessments"

  recurring_scans {
    enabled                   = true
    email_subscription_admins = true
  }

  depends_on = [
    azurerm_mssql_server_security_alert_policy.sql_security_alerts,
    azurerm_storage_account.sql_audit_storage
  ]
}

resource "azurerm_storage_account" "func_storage" {
  name                     = "stfunc${lower(replace(module.resource_group[local.default_environment].name, "-", ""))}"
  resource_group_name      = module.resource_group[local.default_environment].name
  location                 = "Canada Central"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "func_plan" {
  name                = "plan-jit-access"
  resource_group_name = module.resource_group[local.default_environment].name
  location            = "Canada Central"
  os_type             = "Linux" # Linux is preferred for .NET 8 / Python
  sku_name            = "Y1"    # Consumption (Serverless) tier
}

resource "azurerm_linux_function_app" "jit_function" {
  name                = "func-jit-access-${lower(replace(module.resource_group[local.default_environment].name, "-", ""))}"
  resource_group_name = module.resource_group[local.default_environment].name
  location            = "Canada Central"

  storage_account_name       = azurerm_storage_account.func_storage.name
  storage_account_access_key = azurerm_storage_account.func_storage.primary_access_key
  service_plan_id            = azurerm_service_plan.func_plan.id

  site_config {
    application_stack {
      dotnet_version              = "8.0"
      use_dotnet_isolated_runtime = true
    }
    always_on = false
    cors {
      allowed_origins = ["https://portal.azure.com"] # Allows communication through the Azure Portal
      support_credentials = true
    }
  }
  

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "SQL_SERVER_NAME"                       = azurerm_mssql_server.sql_server.name
    "SUBSCRIPTION_ID"                       = data.azurerm_client_config.current.subscription_id
    "RESOURCE_GROUP_NAME"                   = module.resource_group[local.default_environment].name
    "FUNCTIONS_WORKER_RUNTIME"              = "dotnet-isolated"
    "AzureWebJobsStorage"                   = azurerm_storage_account.func_storage.primary_connection_string
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.app_insights.connection_string
  }

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
      app_settings["WEBSITE_CONTENTAZUREFILECONNECTIONSTRING"],
      app_settings["WEBSITE_CONTENTSHARE"],
      tags
    ]
  }
}
