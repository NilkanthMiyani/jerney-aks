output "cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.main.name
}

output "resource_group" {
  description = "Azure Resource Group"
  value       = azurerm_resource_group.main.name
}

output "vnet_name" {
  description = "Virtual network name"
  value       = azurerm_virtual_network.this.name
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.main.vault_uri
}

output "eso_client_id" {
  description = "ESO managed identity client ID"
  value       = azurerm_user_assigned_identity.eso.client_id
}

output "oidc_issuer_url" {
  description = "AKS OIDC issuer URL"
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "kubectl_config_command" {
  description = "Run this to configure kubectl"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
}
