# ============================================================================
# Azure Function App for Just-In-Time Access
# ============================================================================

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
      allowed_origins     = ["https://portal.azure.com"] # Allows communication through the Azure Portal
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