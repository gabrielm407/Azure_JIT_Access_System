# ============================================================================
# Key Vault for Customer-Managed Keys (CMK) Encryption
# ============================================================================

resource "azurerm_key_vault" "sql_cmk_vault" {
  name                = "sqlcmk${lower(replace(module.resource_group[local.default_environment].name, "-", ""))}"
  location            = module.resource_group[local.default_environment].location
  resource_group_name = module.resource_group[local.default_environment].name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "premium"

  # Enable for disk encryption
  enabled_for_disk_encryption = true
  enabled_for_template_deployment = true
  enabled_for_deployment = true
  
  # Network security
  public_network_access_enabled = false
  purge_protection_enabled      = true
  soft_delete_retention_days    = 90

  tags = {
    purpose       = "sql-cmk-encryption"
    encryption    = "customer-managed-keys"
    compliance    = "required"
    environment   = local.default_environment
  }

  depends_on = [module.resource_group]
}

# Key Vault Private Endpoint
resource "azurerm_private_endpoint" "keyvault_private_endpoint" {
  name                = "${azurerm_key_vault.sql_cmk_vault.name}-private-endpoint"
  location            = module.resource_group[local.default_environment].location
  resource_group_name = module.resource_group[local.default_environment].name
  subnet_id           = module.virtual_network.subnet_id

  private_service_connection {
    name                           = "${azurerm_key_vault.sql_cmk_vault.name}-psc"
    private_connection_resource_id = azurerm_key_vault.sql_cmk_vault.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  tags = module.resource_group[local.default_environment].tags
}

# Private DNS Zone for Key Vault
resource "azurerm_private_dns_zone" "keyvault_dns" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = module.resource_group[local.default_environment].name

  tags = module.resource_group[local.default_environment].tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault_vnet_link" {
  name                  = "${azurerm_key_vault.sql_cmk_vault.name}-vnet-link"
  resource_group_name   = module.resource_group[local.default_environment].name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault_dns.name
  virtual_network_id    = module.virtual_network.id
}

# Customer-Managed Key (CMK) for SQL Encryption
resource "azurerm_key_vault_key" "sql_cmk_key" {
  count            = var.enable_cmk_encryption ? 1 : 0
  name             = "sql-tde-key"
  key_vault_id     = azurerm_key_vault.sql_cmk_vault.id
  key_type         = "RSA"
  key_size         = 2048
  
  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey"
  ]

  depends_on = [azurerm_key_vault.sql_cmk_vault]
}

# Key Vault Access Policy for SQL Server
resource "azurerm_key_vault_access_policy" "sql_server_policy" {
  count            = var.enable_cmk_encryption ? 1 : 0
  key_vault_id     = azurerm_key_vault.sql_cmk_vault.id
  tenant_id        = data.azurerm_client_config.current.tenant_id
  object_id        = azurerm_mssql_server.sql_server.identity[0].principal_id

  key_permissions = [
    "Get",
    "List",
    "UnwrapKey",
    "WrapKey",
    "Sign",
    "Verify",
    "Create",
    "Update",
    "Delete",
    "Decrypt",
    "Encrypt"
  ]

  depends_on = [
    azurerm_key_vault.sql_cmk_vault,
    azurerm_mssql_server.sql_server
  ]
}

# Frequently used Data Source
data "azurerm_client_config" "current" {}
