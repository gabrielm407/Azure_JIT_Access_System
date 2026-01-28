# ============================================================================
# Terraform Providers and Backend Configuration
# ============================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "Default Project"

    workspaces {
      name = "Azure_kubernetes_terraform"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.ARM_SUBSCRIPTION_ID
  tenant_id       = var.ARM_TENANT_ID
  client_id       = var.ARM_CLIENT_ID
  client_secret   = var.ARM_CLIENT_SECRET
}
