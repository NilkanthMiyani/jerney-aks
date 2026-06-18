data "azurerm_kubernetes_service_versions" "current" {
  location        = azurerm_resource_group.main.location
  include_preview = false
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.cluster_name}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.cluster_name}-${var.environment}"

  kubernetes_version = coalesce(
    var.kubernetes_version,
    data.azurerm_kubernetes_service_versions.current.latest_version
  )

  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  local_account_disabled    = var.local_account_disabled

  # ---- System Node Pool ----
  default_node_pool {
    name            = "system"
    vm_size         = var.node_vm_size
    vnet_subnet_id  = azurerm_subnet.aks_nodes.id
    os_disk_size_gb = var.disk_size_gb
    os_disk_type    = var.os_disk_type

    temporary_name_for_rotation = "systemtmp"

    auto_scaling_enabled = true
    min_count            = var.min_node_count
    max_count            = var.max_node_count

    node_labels = local.common_tags

    upgrade_settings {
      max_surge = var.upgrade_max_surge
    }
  }

  # ---- Identity ----
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_control_plane.id]
  }

  kubelet_identity {
    client_id                 = azurerm_user_assigned_identity.aks_kubelet.client_id
    object_id                 = azurerm_user_assigned_identity.aks_kubelet.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.aks_kubelet.id
  }

  # ---- Networking ----
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
    network_policy      = "azure"
  }

  tags = local.common_tags
}
