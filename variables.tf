# ============================================================================
# Variable Definitions
# ============================================================================

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
  default     = "my-resource-group"
}

variable "location" {
  description = "The Azure location where resources will be created"
  type        = string
  default     = "eastus"
}

variable "virtual_network_address_space" {
  description = "The address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_name" {
  description = "The name of the subnet within the virtual network"
  type        = string
  default     = "my-subnet"
}

variable "kubernetes_cluster_name" {
  description = "The name of the Kubernetes cluster"
  type        = string
  default     = "my-aks"
}

variable "kubernetes_node_count" {
  description = "The number of nodes in the Kubernetes cluster"
  type        = number
  default     = 1
}

variable "kubernetes_node_size" {
  description = "The size of the nodes in the Kubernetes cluster"
  type        = string
  default     = "Standard_L2as_v4"
}

variable "ARM_CLIENT_SECRET" {
  description = "The client secret for the Azure service principal"
  type        = string
  sensitive   = true
}

variable "ARM_SUBSCRIPTION_ID" {
  description = "The Azure Subscription ID"
  type        = string
}

variable "ARM_TENANT_ID" {
  description = "The tentant ID for the Azure service principal"
  type        = string
}

variable "ARM_CLIENT_ID" {
  description = "The client ID for the Azure service principal"
  type        = string
}

variable "sql_admin_username" {
  description = "The SQL Server administrator username"
  type        = string
  sensitive   = true
}

variable "sql_admin_password" {
  description = "The SQL Server administrator password"
  type        = string
  sensitive   = true
}

variable "enable_cmk_encryption" {
  description = "Enable Customer-Managed Key (CMK) encryption for SQL Server TDE"
  type        = bool
  default     = false
}

variable "sql_audit_retention_days" {
  description = "Number of days to retain SQL audit logs"
  type        = number
  default     = 30
  validation {
    condition     = var.sql_audit_retention_days >= 0 && var.sql_audit_retention_days <= 3650
    error_message = "Audit retention days must be between 0 and 3650."
  }
}

variable "enable_vulnerability_assessment" {
  description = "Enable SQL Server Vulnerability Assessment scans"
  type        = bool
  default     = true
}

variable "enable_security_alerts" {
  description = "Enable SQL Server Advanced Data Security alerts"
  type        = bool
  default     = true
}

variable "enable_auditing" {
  description = "Enable SQL Server auditing"
  type        = bool
  default     = true
}

variable "compliance_tags" {
  description = "Tags for compliance and auditing purposes"
  type        = map(string)
  default = {
    compliance_framework = "Azure Policy"
    encryption_enabled   = "true"
    tde_enabled          = "true"
    audit_enabled        = "true"
  }
}