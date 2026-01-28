# ============================================================================
# Virtual network
# ============================================================================

module "virtual_network" {
  source              = "./modules/virtual_network"
  resource_group_name = module.resource_group[local.default_environment].name
  location            = module.resource_group[local.default_environment].location
  tags                = module.resource_group[local.default_environment].tags
  address_space       = var.virtual_network_address_space
  subnet_name         = var.subnet_name
  address_spaces      = ["10.0.1.0/24"]
  service_endpoints   = ["Microsoft.Storage"]

  depends_on = [module.resource_group]
}