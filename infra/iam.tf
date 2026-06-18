# ---- Control Plane Identity ----
resource "azurerm_user_assigned_identity" "aks_control_plane" {
  name                = "${var.cluster_name}-identity"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

# ---- Kubelet (Node) Identity ----
resource "azurerm_user_assigned_identity" "aks_kubelet" {
  name                = "${var.cluster_name}-kubelet-identity"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

# ---- ESO Identity ----
resource "azurerm_user_assigned_identity" "eso" {
  name                = "${var.cluster_name}-eso-identity"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

# ---- Role Assignments ----
resource "azurerm_role_assignment" "aks_control_plane_network" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_control_plane.principal_id
}

resource "azurerm_role_assignment" "aks_kubelet_mi_operator" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.aks_control_plane.principal_id
}

# ---- ESO Federated Credential ----
resource "azurerm_federated_identity_credential" "eso" {
  name                      = "eso-federated-credential"
  resource_group_name       = azurerm_resource_group.main.name
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.main.oidc_issuer_url
  user_assigned_identity_id = azurerm_user_assigned_identity.eso.id
  subject                   = "system:serviceaccount:external-secrets:external-secrets"
  depends_on                = [azurerm_kubernetes_cluster.main]
}
