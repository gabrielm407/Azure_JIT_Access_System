# ============================================================================
# Azure Kubernetes Service (AKS) Cluster Deployment
# ============================================================================

# module "aks" {
#   source                  = "./modules/aks"
#   kubernetes_cluster_name = var.kubernetes_cluster_name
#   resource_group_name     = module.resource_group[local.default_environment].name
#   location                = module.resource_group[local.default_environment].location
#   dns_prefix              = "myaks01"
#   kubernetes_node_count   = var.kubernetes_node_count
#   kubernetes_node_size    = var.kubernetes_node_size

#   depends_on = [ module.virtual_network ]
# }