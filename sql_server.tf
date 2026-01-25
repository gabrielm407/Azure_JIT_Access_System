# Azure SQL Server with Public Network Access disabled
resource "azurerm_mssql_server" "sql_server" {
  name                         = "sqlserver-${lower(replace(var.resource_group_name, "-", ""))}-${formatdate("MMdd", timestamp())}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password
  public_network_access_enabled = false

  tags = azurerm_resource_group.rg.tags
}

# Azure SQL Database
resource "azurerm_mssql_database" "sql_database" {
  name           = "sentineldb"
  server_id      = azurerm_mssql_server.sql_server.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  sku_name       = "S0"
  zone_redundant = false

  tags = azurerm_resource_group.rg.tags
}

# Private Endpoint for SQL Server (required since public network access is disabled)
resource "azurerm_private_endpoint" "sql_private_endpoint" {
  name                = "${azurerm_mssql_server.sql_server.name}-private-endpoint"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet.id

  private_service_connection {
    name                           = "${azurerm_mssql_server.sql_server.name}-psc"
    private_connection_resource_id = azurerm_mssql_server.sql_server.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  tags = azurerm_resource_group.rg.tags
}

# Private DNS Zone for SQL Server
resource "azurerm_private_dns_zone" "sql_dns" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.rg.name

  tags = azurerm_resource_group.rg.tags
}

# Private DNS Zone Virtual Network Link
resource "azurerm_private_dns_zone_virtual_network_link" "sql_vnet_link" {
  name                  = "${azurerm_mssql_server.sql_server.name}-vnet-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.sql_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# DNS A Record for SQL Server
resource "azurerm_private_dns_a_record" "sql_dns_record" {
  name                = azurerm_mssql_server.sql_server.name
  zone_name           = azurerm_private_dns_zone.sql_dns.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.sql_private_endpoint.private_service_connection[0].private_ip_address]
}

# Deny public network access (additional security measure)
resource "azurerm_mssql_server_transparent_data_encryption" "sql_tde" {
  server_id = azurerm_mssql_server.sql_server.id
}
