# # module "storage_account" {
# #   source   = "git::https://github.com/Azure-Terraform/terraform-azurerm-storage-account.git?ref=v1.2.0"
# #   for_each = toset(local.environments)

# #   resource_group_name = module.resource_group[each.key].name
# #   name                = "mystorageacct${each.value}405" # Adding 405 at the end to ensure uniqueness, as storage account names must be globally unique
# #   location            = module.resource_group[each.key].location
# #   tags                = module.resource_group[each.key].tags

# #   public_network_access_enabled = true
# #   replication_type              = "LRS"
# #   enable_large_file_share       = true
# #   shared_access_key_enabled     = true

# #   access_list = {
# #     "my_ip" = "0.0.0.0/0"
# #   }

# #   service_endpoints = {
# #     "my-subnet" = module.virtual_network.subnet_id
# #   }

# #   enable_static_website = true

# #   blob_cors = {
# #     test = {
# #       allowed_headers    = ["*"]
# #       allowed_methods    = ["GET", "DELETE"]
# #       allowed_origins    = ["*"]
# #       exposed_headers    = ["*"]
# #       max_age_in_seconds = 5
# #     }
# #   }

# #   depends_on = [module.virtual_network] # This isn't required since Terraform is smart enough to figure it out since it references the virtual network module on line 21 and knows that module must be created first
# # }

# # Storage Account for SQL Auditing and Vulnerability Assessment

# resource "azurerm_storage_account" "sql_audit_storage" {
#   name                     = "sql${lower(replace(module.resource_group[local.default_environment].name, "-", ""))}"
#   resource_group_name      = module.resource_group[local.default_environment].name
#   location                 = module.resource_group[local.default_environment].location
#   account_tier             = "Standard"
#   account_replication_type = "GRS"
  
#   # Enable encryption at rest
#   https_traffic_only_enabled = true
#   min_tls_version            = "TLS1_2"

#   # Network rules for enhanced security
#   public_network_access_enabled = true
#   shared_access_key_enabled     = true

#   network_rules {
#     default_action = "Deny"
#     ip_rules       = ["0.0.0.0/0"] # This allows all traffic, but it is better to be only your public IP address
#     bypass         = ["AzureServices"] # Optional: often needed for metrics/logging
#   }

#   tags = {
#     purpose       = "sql-audit-and-vulnerability-assessment"
#     encryption    = "enabled"
#     compliance    = "required"
#     environment   = local.default_environment
#   }

#   depends_on = [module.resource_group, azurerm_role_assignment.storage_blob_data_contributor]
# }

# # Blob container for SQL audit logs
# resource "azurerm_storage_container" "sql_audit_logs" {
#   name                  = "sql-audit-logs"
#   storage_account_name  = azurerm_storage_account.sql_audit_storage.name
#   container_access_type = "private"

#   depends_on = [azurerm_storage_account.sql_audit_storage]
# }

# # Blob container for vulnerability assessments
# resource "azurerm_storage_container" "vulnerability_assessments" {
#   name                  = "vulnerability-assessments"
#   storage_account_name  = azurerm_storage_account.sql_audit_storage.name
#   container_access_type = "private"

#   depends_on = [azurerm_storage_account.sql_audit_storage]
# }
