locals {
  kubeconfig_path = pathexpand(var.kubeconfig_path)
}

provider "kubernetes" {
  config_path    = local.kubeconfig_path
  config_context = var.kubeconfig_context
}

provider "helm" {
  kubernetes {
    config_path    = local.kubeconfig_path
    config_context = var.kubeconfig_context
  }
}
