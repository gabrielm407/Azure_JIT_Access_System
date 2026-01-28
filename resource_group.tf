# ============================================================================
# Resource Groups for each environment
# ============================================================================

module "resource_group" {
  source   = "./modules/resource_group"
  for_each = toset(local.environments)

  name     = "my-resourcegroup-${each.value}"
  location = var.location
  tags = {
    environment = "${each.value}"
  }
}