# ---- 1. ArgoCD ----
resource "helm_release" "argocd" {
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  timeout          = 300

  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

  set {
    name  = "configs.cm.application\\.instanceLabelKey"
    value = "argocd.argoproj.io/instance"
  }

  depends_on = [azurerm_kubernetes_cluster.main]
}

# ---- 2. External Secrets Operator ----
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.eso_chart_version
  namespace        = "external-secrets"
  create_namespace = true
  wait             = true
  timeout          = 300

  # Use a values block (not `set`) so the label value is rendered as a quoted
  # string. The azure-wi-webhook mutates pods (not ServiceAccounts) whose labels
  # match azure.workload.identity/use=true, so the label must land on the pod
  # template; k8s label values must be strings.
  values = [
    yamlencode({
      serviceAccount = {
        annotations = {
          "azure.workload.identity/client-id" = azurerm_user_assigned_identity.eso.client_id
          # ESO's azurekv WorkloadIdentity path reads the tenant from this SA
          # annotation (the store's tenantId field is not used here).
          "azure.workload.identity/tenant-id" = data.azurerm_client_config.current.tenant_id
        }
      }
      podLabels = {
        "azure.workload.identity/use" = "true"
      }
    })
  ]

  depends_on = [
    azurerm_kubernetes_cluster.main,
    azurerm_role_assignment.aks_kubelet_mi_operator # ensure identity is fully setup
  ]
}

# ---- 3. ClusterSecretStore (Azure Key Vault) ----
# Uses a local Helm chart because the Helm provider does NOT validate CRDs
# at plan time. (ESO CRDs are installed by step 2 above).
resource "helm_release" "eso_cluster_secret_store" {
  name      = "eso-cluster-store"
  chart     = "${path.module}/charts/cluster-secret-store"
  namespace = "external-secrets"

  set {
    name  = "tenantId"
    value = data.azurerm_client_config.current.tenant_id
  }

  set {
    name  = "vaultUrl"
    value = azurerm_key_vault.main.vault_uri
  }

  depends_on = [helm_release.external_secrets]
}

# ---- 4. Root App-of-Apps (via argocd-apps chart) ----
resource "helm_release" "argocd_apps" {
  name             = "argocd-apps"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd-apps"
  version          = var.argocd_apps_chart_version
  namespace        = "argocd"
  create_namespace = false

  values = [
    yamlencode({
      applications = {
        platform = {
          namespace = "argocd"
          finalizers = [
            "resources-finalizer.argocd.argoproj.io"
          ]
          project = "default"
          source = {
            repoURL        = var.gitops_repo_url
            targetRevision = var.gitops_target_revision
            path           = var.gitops_apps_path
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "argocd"
          }
          syncPolicy = {
            automated = {
              prune    = true
              selfHeal = true
            }
          }
        }
      }
    })
  ]

  depends_on = [helm_release.argocd]
}
