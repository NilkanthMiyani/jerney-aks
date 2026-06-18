# AKS Reference

AKS-specific patterns, resources, and gotchas for the gitops-infra skill.

## Providers

```hcl
required_providers {
  azurerm    = { source = "hashicorp/azurerm",    version = "~> 4.0"  }
  helm       = { source = "hashicorp/helm",       version = "~> 2.16" }
  kubernetes = { source = "hashicorp/kubernetes",  version = "~> 2.23" }
  tls        = { source = "hashicorp/tls",        version = "~> 4.0"  }
}
```

**AzureRM requires a `features {}` block** in the provider config (even if empty).

## Backend

Azure Storage Account with blob container.

```hcl
backend "azurerm" {
  resource_group_name  = "<rg>"
  storage_account_name = "<account>"
  container_name       = "tfstate"
  key                  = "<project>/terraform.tfstate"
}
```

Locking is built-in via blob leases.

## Networking (networking.tf)

- Resource Group (all resources belong to one).
- VNet with custom subnets.
- Separate subnets for: AKS nodes, AKS pods (if using Azure CNI Overlay), application gateways.
- NSGs (Network Security Groups) for subnet-level firewall rules.
- No NAT Gateway needed for basic egress (AKS uses load balancer outbound rules by default). Add NAT Gateway for stable egress IPs.

## IAM (iam.tf)

AKS uses Azure AD + Managed Identities:

- **System-assigned identity** on the AKS cluster (simplest).
- **User-assigned identity** for more control (recommended for prod).
- Role assignments: `Network Contributor` on VNet (if using custom VNet), `AcrPull` on ACR.

No equivalent of AWS IAM roles for service accounts in the traditional sense — AKS uses **Workload Identity** (Azure AD federated credentials).

## AKS Cluster (aks-cluster.tf)

- `azurerm_kubernetes_cluster` with `default_node_pool`.
- Azure CNI or kubenet for networking.
- Workload Identity enabled: `oidc_issuer_enabled = true`, `workload_identity_enabled = true`.
- Azure Key Vault Secrets Provider as an addon (alternative to ESO).
- AKS manages CoreDNS and kube-proxy automatically — no addon resources needed.

## Workload Identity (irsa.tf equivalent)

AKS Workload Identity pattern:

1. Create Azure AD Application / User-Assigned Managed Identity.
2. Create federated credential linking K8s SA → Azure identity.
3. Annotate K8s SA with `azure.workload.identity/client-id`.

```
azurerm_user_assigned_identity → azurerm_federated_identity_credential → K8s SA annotation
```

### Workload Identity Roles Needed

| Service | Identity | Key Roles |
|---------|----------|-----------|
| ESO | <project>-eso | Key Vault Secrets User |
| Cert Manager (if used) | <project>-cert-manager | DNS Zone Contributor |

## Node Scaling

AKS supports both:
- **Cluster Autoscaler**: built-in, enabled via `auto_scaling_enabled = true` on the node pool. No Helm install needed.
- **Karpenter (NAP)**: AKS adopted Karpenter via Node Auto Provisioning (GA 2026). Same NodePool CRD as EKS.

For standard AKS clusters, enable autoscaling on the node pool:

```hcl
resource "azurerm_kubernetes_cluster" "main" {
  default_node_pool {
    auto_scaling_enabled = true
    min_count            = var.min_node_count
    max_count            = var.max_node_count
  }
}
```

KEDA is also available as a native AKS addon for event-driven pod autoscaling (scale to zero).

## Ingress

AKS options:
- **NGINX Ingress Controller**: Helm install, most portable across clouds.
- **Application Gateway Ingress Controller (AGIC)**: Azure-native L7 load balancer.
- **Azure ALB Controller (preview)**: similar to AWS ALB Controller.

cert-manager + Let's Encrypt is the standard for TLS on AKS (no ACM equivalent).

## Secrets

Azure Key Vault. Two approaches:
- **ESO with Key Vault**: ClusterSecretStore uses `provider: azurekv`. Consistent with EKS/GKE pattern.
- **AKS Key Vault Secrets Provider addon**: CSI driver that mounts Key Vault secrets as volumes. Azure-native but less flexible than ESO.

Recommend ESO for consistency across clouds.

## Bootstrap (bootstrap.tf)

Install order:
1. StorageClass: AKS default `managed-csi` is usually fine. For premium SSD, create `managed-csi-premium`.
2. `helm_release.argocd` → `helm_release.argocd_apps`
3. `helm_release.external_secrets` (with Workload Identity annotation)
4. `helm_release.nginx_ingress` (if using NGINX) or AGIC via AKS addon
5. `helm_release.cert_manager` (if using Let's Encrypt)

No Cluster Autoscaler Helm install needed if using built-in auto-scaling.

## AKS-Specific Helm Values

```yaml
# StorageClass
postgresql.primary.persistence.storageClass: "managed-csi"

# Ingress (NGINX)
ingress.class: "nginx"
ingress.annotations:
  cert-manager.io/cluster-issuer: "letsencrypt-prod"

# NetworkPolicy
networkPolicy.vpcCidr: "<vnet-subnet-cidr>"
```

## AKS Gotchas

1. **Resource Group scope**: Azure creates a second resource group (`MC_*`) for node resources. Don't manually modify it.
2. **AKS manages its own upgrades**: node image upgrades happen automatically unless disabled. Control via `maintenance_window`.
3. **Terraform destroy order**: AKS load balancer public IPs can block VNet/subnet deletion. Delete services with `type: LoadBalancer` first.
4. **cert-manager ACME HTTP-01 timeouts**: if using HTTP-01 challenges, ensure the ingress controller can route `.well-known/acme-challenge` before cert issuance.
5. **ArgoCD overwriting Terraform-managed secrets**: if both ArgoCD and Terraform manage the same secret, ArgoCD's selfHeal will fight Terraform. Pick one owner.
6. **`app.kubernetes.io/instance` label collision**: same fix as EKS — set `application.instanceLabelKey: argocd.argoproj.io/instance` in ArgoCD config.
7. **NetworkPolicy + NGINX**: if using NetworkPolicies, ensure the policy allows traffic from the NGINX ingress controller namespace to app namespaces.