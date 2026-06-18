# ==============================================================
# Bootstrap — creates the Azure Storage Account used as the
# Terraform remote backend for infra/.
#
# Uses local state intentionally — this module is the
# prerequisite that makes remote state possible.
# ==============================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Azure region for the state storage account"
  type        = string
  default     = "eastus"
}

# Storage account names must be globally unique, 3–24 lowercase alphanumeric
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_resource_group" "tfstate" {
  name     = "jerney-tfstate-rg"
  location = var.location
}

resource "azurerm_storage_account" "tfstate" {
  name                     = "jerneytfstate${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = azurerm_resource_group.tfstate.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  blob_properties {
    versioning_enabled = true
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

output "storage_account_name" {
  description = "Set this as storage_account_name in infra/versions.tf backend block"
  value       = azurerm_storage_account.tfstate.name
}

output "resource_group_name" {
  description = "Resource group holding the state storage account"
  value       = azurerm_resource_group.tfstate.name
}

output "container_name" {
  description = "Blob container name for remote state"
  value       = azurerm_storage_container.tfstate.name
}
