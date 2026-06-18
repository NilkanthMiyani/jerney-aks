terraform {
  required_version = "~> 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {
    # Terraform Workspaces will automatically isolate state via environment prefixes in the container.
    resource_group_name  = "jerney-tfstate-rg"
    storage_account_name = "jerneytfstate6d4ehw" # from bootstrap output
    container_name       = "tfstate"
    key                  = "jerney-aks/terraform.tfstate"
  }
}
