resource "random_id" "kv_suffix" {
  byte_length = 2
}

resource "azurerm_key_vault" "main" {
  name                = "${substr(var.cluster_name, 0, 14)}-kv-${random_id.kv_suffix.hex}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled = true
  soft_delete_retention_days = var.soft_delete_retention_days
  purge_protection_enabled   = var.purge_protection_enabled

  tags = local.common_tags
}

# Grant deployer Key Vault Administrator so Terraform can create secrets
resource "azurerm_role_assignment" "deployer_kv_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Grant ESO identity read access to Key Vault secrets
resource "azurerm_role_assignment" "eso_kv_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.eso.principal_id
}

locals {
  secrets_map = {
    "jerney-postgres-password"      = var.postgres_password
    "jerney-grafana-admin-password" = var.grafana_admin_password
    "jerney-alertmanager-smtp-key"  = var.alertmanager_smtp_key
  }
}

resource "azurerm_key_vault_secret" "secrets" {
  for_each = nonsensitive(toset(keys(local.secrets_map)))

  name         = each.value
  value        = local.secrets_map[each.value]
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.deployer_kv_admin]
}
