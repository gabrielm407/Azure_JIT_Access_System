# ============================================================================
# Monitoring Resources: Log Analytics and Application Insights
# ============================================================================

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "analytics" {
  name                = "law-${lower(replace(module.resource_group[local.default_environment].name, "-", ""))}"
  location            = "Canada Central" # Location matches the resources being monitored
  resource_group_name = module.resource_group[local.default_environment].name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Application Insights
resource "azurerm_application_insights" "app_insights" {
  name                = "appi-${lower(replace(module.resource_group[local.default_environment].name, "-", ""))}"
  location            = "Canada Central" # Location matches the resources being monitored
  resource_group_name = module.resource_group[local.default_environment].name
  workspace_id        = azurerm_log_analytics_workspace.analytics.id
  application_type    = "web"
}