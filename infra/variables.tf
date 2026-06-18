# ==============================================================
# Workspace Environment — Input Variables
# ==============================================================

# ---- Azure Context ----
variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9a-f]{8}-", var.subscription_id))
    error_message = "subscription_id must be a valid UUID."
  }
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
  nullable    = false
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  nullable    = false
}

variable "environment" {
  description = "The environment name (e.g., dev, staging, prod)"
  type        = string
  nullable    = false
}

# ---- Cluster ----
variable "cluster_name" {
  description = "AKS cluster name"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,61}[a-z0-9]$", var.cluster_name))
    error_message = "cluster_name must be 3–63 chars, lowercase alphanumeric and hyphens."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version (null = latest stable)"
  type        = string
  default     = null
}

variable "local_account_disabled" {
  description = "Disable local accounts on AKS cluster"
  type        = bool
  default     = false
}

# ---- Node Pool ----
variable "node_vm_size" {
  description = "VM size for system node pool"
  type        = string
  default     = "Standard_D2s_v7"
  nullable    = false
}

variable "min_node_count" {
  description = "Minimum nodes"
  type        = number
  default     = 1
  nullable    = false
}

variable "max_node_count" {
  description = "Maximum nodes"
  type        = number
  default     = 3
  nullable    = false
}

variable "disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 30
  nullable    = false
}

variable "os_disk_type" {
  description = "OS disk type (Managed or Ephemeral)"
  type        = string
  default     = "Managed"
}

variable "upgrade_max_surge" {
  description = "Max surge during upgrades"
  type        = string
  default     = "10%"
}

# ---- Networking ----
variable "vnet_address_space" {
  description = "VNet CIDR"
  type        = string
  default     = "10.0.0.0/16"
  nullable    = false
}

variable "subnet_address_prefix" {
  description = "AKS node subnet CIDR"
  type        = string
  default     = "10.0.0.0/24"
  nullable    = false
}

variable "pod_cidr" {
  description = "CIDR range for pods (Azure CNI Overlay)"
  type        = string
  default     = "10.100.0.0/14"
}

variable "service_cidr" {
  description = "CIDR range for services"
  type        = string
  default     = "10.104.0.0/20"
}

variable "dns_service_ip" {
  description = "IP address within the Kubernetes service address range that will be used by cluster service discovery"
  type        = string
  default     = "10.104.0.10"
}

# ---- GitOps ----
variable "gitops_repo_url" {
  description = "Git repo URL for ArgoCD"
  type        = string
  nullable    = false
}

variable "gitops_target_revision" {
  description = "Git branch/tag for ArgoCD"
  type        = string
  default     = "main"
  nullable    = false
}

variable "gitops_apps_path" {
  description = "Path to ArgoCD app manifests in the repo"
  type        = string
  nullable    = false
}

variable "argocd_chart_version" {
  description = "ArgoCD Helm chart version (chart 9.5.x ships ArgoCD v3.4.x)"
  type        = string
  default     = "9.5.21"
}

variable "argocd_apps_chart_version" {
  description = "ArgoCD Apps Helm chart version"
  type        = string
  default     = "2.0.5"
}

variable "eso_chart_version" {
  description = "External Secrets Operator Helm chart version (2.x ships ESO v2.x)"
  type        = string
  default     = "2.6.0"
}

# ---- Key Vault ----
variable "soft_delete_retention_days" {
  description = "Days to retain soft-deleted keys"
  type        = number
  default     = 7
}

variable "purge_protection_enabled" {
  description = "Enable purge protection for Key Vault"
  type        = bool
  default     = false
}

# ---- Secrets ----
variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
  nullable    = false
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  nullable    = false
}

variable "alertmanager_smtp_key" {
  description = "Alertmanager SMTP API key"
  type        = string
  sensitive   = true
  nullable    = false
}
